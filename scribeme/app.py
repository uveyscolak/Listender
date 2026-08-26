"""ScribeMe menü barı uygulaması — orkestrasyon.

rumps menü barı + pynput global listener. Sağ Option (⌥) basılı tutulunca
kayıt başlar, bırakılınca: whisper transkript → temizlik → enjeksiyon.
Ağır işler worker thread'de yürür (rumps ana thread'i kilitler).
"""

import threading
import time

import rumps
from pynput import keyboard
from PyObjCTools import AppHelper

from . import cleaner, config, injector
from .recorder import Recorder
from .transcriber import Transcriber

# Durum ikonları
ICON_IDLE = "🎙️"
ICON_LOADING = "⏳"
ICON_RECORDING = "🔴"
ICON_PROCESSING = "✍️"
ICON_NO_MIC = "🚫"          # mikrofon yok — bas-konuş devre dışı


class ScribeMeApp(rumps.App):
    def __init__(self):
        super().__init__("ScribeMe", title=ICON_LOADING, quit_button=None)

        self.recorder = Recorder()
        self.transcriber = Transcriber(status_callback=self._set_status)
        self.use_llm = config.OLLAMA_ENABLED_DEFAULT

        self._model_loaded = False   # whisper belleğe alındı mı
        self._mic_ok = False         # mikrofon var + stream açık mı
        self._recording = False
        self._record_started_at = 0.0
        self._lock = threading.Lock()

        # Menü
        self.status_item = rumps.MenuItem("Başlatılıyor…")
        self.llm_item = rumps.MenuItem("LLM temizliği (Ollama)", callback=self._toggle_llm)
        self.menu = [
            self.status_item,
            None,
            self.llm_item,
            None,
            rumps.MenuItem("Çıkış", callback=self._quit),
        ]
        self._refresh_llm_check()

        # Ağır açılışı (model yükleme) worker'a al: UI'ı bloklamasın.
        threading.Thread(target=self._load_model, daemon=True).start()

        # v1'de launcher'ın yaptığı iş: Ollama kuruluysa servisi başlat.
        # (.app'te launcher yok; kurulu değilse sessizce geçer — LLM opsiyonel.)
        threading.Thread(
            target=cleaner.start_ollama_if_installed, daemon=True
        ).start()

        # Mikrofon durumunu periyodik yokla: takılınca otomatik gelsin,
        # çekilince bas-konuş devre dışı kalsın. (rumps.Timer ana thread'de.)
        self._mic_timer = rumps.Timer(self._poll_mic, 2)
        self._mic_timer.start()

        # Global klavye dinleyicisi
        self._listener = keyboard.Listener(
            on_press=self._on_press, on_release=self._on_release
        )
        self._listener.start()

    # --- Açılış / model ---

    def _load_model(self):
        try:
            self.transcriber.load()
            self._model_loaded = True
            self._update_idle_state()
        except Exception as e:
            import traceback
            traceback.print_exc()  # bundled modda /tmp/scribeme.log'a düşer
            self._set_status(f"Model hatası: {e}")
            self._set_title("⚠️")

    def _ready(self) -> bool:
        """Bas-konuş için hazır mı: model yüklü ve mikrofon açık."""
        return self._model_loaded and self._mic_ok

    def _update_idle_state(self):
        """Kayıt/işleme dışındayken doğru boşta ikonunu/durumunu göster."""
        if self._recording:
            return
        if not self._model_loaded:
            self._set_title(ICON_LOADING)
            self._set_status("Model yükleniyor…")
        elif not self._mic_ok:
            self._set_title(ICON_NO_MIC)
            self._set_status("Mikrofon yok — bağlanınca otomatik hazır olur")
        else:
            self._set_title(ICON_IDLE)
            self._set_status("Hazır — sağ ⌥ bas-konuş")

    # --- Mikrofon yoklama (hot-plug) ---

    def _poll_mic(self, _timer):
        if self._recording:
            return

        if self._mic_ok:
            # Stream açıkken PortAudio'ya DOKUNMA: refresh_devices
            # (sd._terminate/_initialize) aktif stream'i sessizce öldürür
            # (kanıtlandı, bkz. Bug-Defteri 2026-07-03). Sadece sağlık kontrolü:
            # callback akışı durduysa mikrofon çekilmiş/stream ölmüş demektir.
            if not self.recorder.stream_alive():
                print("[mikrofon] callback akışı durdu — stream kapatılıyor",
                      flush=True)
                self._mic_ok = False
                try:
                    self.recorder.stop_stream()
                except Exception:
                    pass
                self._update_idle_state()
            return

        # Mikrofon yok → cache'i tazele ki sonradan takılan aygıt görünsün.
        # (Stream kapalıyken _terminate/_initialize güvenli.)
        Recorder.refresh_devices()
        if Recorder.has_input_device():
            try:
                self.recorder.start_stream()
                self._mic_ok = True
                self._update_idle_state()
            except Exception:
                self._mic_ok = False

    # --- Durum/UI (ana thread'e köprü) ---
    # AppKit (menü, ikon) SADECE ana thread'den güncellenebilir. Worker/pynput
    # thread'inden doğrudan atama menü açıkken SIGTRAP ile çökertir (canlıda
    # yaşandı: NSMenuItem.setTitle @ Thread _process — 2026-07-03 crash raporu).
    # Bu yüzden her UI dokunuşu AppHelper.callAfter ile ana thread'e taşınır.

    def _set_status(self, msg: str):
        AppHelper.callAfter(self._set_status_main, msg)

    def _set_status_main(self, msg: str):
        self.status_item.title = msg

    def _set_title(self, icon: str):
        AppHelper.callAfter(self._set_title_main, icon)

    def _set_title_main(self, icon: str):
        self.title = icon

    def _refresh_llm_check(self):
        available = cleaner.ollama_available()
        if self.use_llm and available:
            self.llm_item.state = 1
            self.llm_item.title = "LLM temizliği (Ollama) ✓ açık"
        elif self.use_llm and not available:
            self.llm_item.state = 0
            self.llm_item.title = "LLM temizliği — Ollama erişilemez"
        else:
            self.llm_item.state = 0
            self.llm_item.title = "LLM temizliği (Ollama) — kapalı"

    def _toggle_llm(self, _):
        if self.use_llm:
            # Kapatma her zaman serbest.
            self.use_llm = False
            self._refresh_llm_check()
            return

        # Açma: Ollama + model hazır değilse kullanıcıyı yönlendir.
        if cleaner.ollama_available():
            self.use_llm = True
            self._refresh_llm_check()
            return

        if cleaner.ollama_binary() is None:
            # Ollama kurulu değil → indirme sayfasına yönlendir.
            clicked = rumps.alert(
                title="Ollama kurulu değil",
                message=(
                    "LLM temizliği için Ollama gerekir (ücretsiz, yerel çalışır).\n"
                    "İndirme sayfasını açayım mı? Kurduktan sonra bu menüden "
                    "tekrar açabilirsin.\n\nDikte, LLM olmadan da tam çalışır."
                ),
                ok="İndirme sayfasını aç", cancel="Vazgeç",
            )
            if clicked == 1:
                import subprocess
                subprocess.Popen(["open", config.OLLAMA_DOWNLOAD_URL])
            return

        # Ollama kurulu ama model eksik (veya servis yeni kalkıyor) → çekmeyi öner.
        clicked = rumps.alert(
            title="LLM modeli eksik",
            message=(
                f"Ollama kurulu ama {config.OLLAMA_MODEL} modeli yok.\n"
                "Şimdi indireyim mi? (~2.5 GB, bir kez — arka planda iner, "
                "bitince LLM temizliği otomatik açılır.)"
            ),
            ok="İndir", cancel="Vazgeç",
        )
        if clicked == 1:
            self._set_status("LLM modeli indiriliyor…")
            threading.Thread(target=self._pull_llm_model, daemon=True).start()

    def _pull_llm_model(self):
        """Ollama modelini arka planda çek; bitince LLM'i aç. (Worker thread.)"""
        cleaner.start_ollama_if_installed()
        time.sleep(1.0)  # serve yeni başladıysa soluklan
        ok = cleaner.pull_model(progress_callback=self._set_status)
        if ok and cleaner.ollama_available():
            self.use_llm = True
            self._set_status("LLM modeli hazır — temizlik açıldı")
        else:
            self._set_status("LLM modeli indirilemedi — internet var mı?")
        AppHelper.callAfter(self._refresh_llm_check)

    def _quit(self, _):
        try:
            self._mic_timer.stop()
        except Exception:
            pass
        try:
            self._listener.stop()
        except Exception:
            pass
        try:
            self.recorder.stop_stream()
        except Exception:
            pass
        rumps.quit_application()

    # --- Tuş olayları ---

    def _on_press(self, key):
        if key == keyboard.Key.alt_r:
            self._begin()

    def _on_release(self, key):
        if key == keyboard.Key.alt_r:
            self._end()

    def _begin(self):
        with self._lock:
            if not self._ready() or self._recording:
                return
            self._recording = True
        self._record_started_at = time.monotonic()
        self.recorder.start_recording(on_limit=self._auto_stop)
        self._set_title(ICON_RECORDING)
        self._set_status("Kayıt… (bırakınca yazılır)")

    def _auto_stop(self):
        """Üst sınır aşıldı — kaydı otomatik bitir, eldeki sesi işle."""
        self._end()

    def _end(self):
        with self._lock:
            if not self._recording:
                return
            self._recording = False
        audio = self.recorder.stop_recording()
        duration = time.monotonic() - self._record_started_at
        self._set_title(ICON_PROCESSING)

        # Halüsinasyon filtresi: çok kısa basmalarda hiçbir şey yapma.
        if duration < config.MIN_RECORD_SEC or len(audio) == 0:
            self._set_title(self._idle_icon())
            self._set_status("Çok kısa — atlandı")
            return

        # Ağır iş (transkript + LLM) worker thread'de.
        threading.Thread(target=self._process, args=(audio,), daemon=True).start()

    def _process(self, audio):
        try:
            import numpy as np
            rms = float(np.sqrt(np.mean(audio ** 2))) if len(audio) else 0.0
            dur = len(audio) / config.SAMPLE_RATE
            print(f"[dikte] kayıt {dur:.1f}sn, {len(audio)} örnek, RMS={rms:.4f}",
                  flush=True)

            # Sessizlik kapısı: sinyal yoksa (verici kapalı vb.) whisper'a hiç
            # gitme — normalize edilmiş gürültü halüsinasyon üretir.
            if rms < config.SILENCE_RMS:
                self._done("Ses yok — mikrofon/verici açık mı?")
                return

            self._set_status("Yazıya çevriliyor…")
            raw = self.transcriber.transcribe(audio)
            print(f"[dikte] ham transkript: {raw!r}", flush=True)
            if not raw.strip():
                self._done("Boş — bir şey duyulmadı")
                return

            self._set_status("Temizleniyor…")
            text = cleaner.clean(raw, use_llm=self.use_llm)
            print(f"[dikte] temiz metin: {text!r}", flush=True)
            if not text.strip():
                self._done("Temizlik sonrası boş")
                return

            injector.inject(text)
            print(f"[dikte] enjekte edildi ({len(text)} karakter)", flush=True)
            preview = text if len(text) <= 40 else text[:37] + "…"
            self._done(f"Yazıldı: {preview}")
        except Exception as e:
            print(f"[dikte] HATA: {e!r}", flush=True)
            self._done(f"Hata: {e}")

    def _idle_icon(self) -> str:
        """Kayıt/işleme dışındayken uygun boşta ikonu (durum mesajını ezmez)."""
        if not self._model_loaded:
            return ICON_LOADING
        if not self._mic_ok:
            return ICON_NO_MIC
        return ICON_IDLE

    def _done(self, msg: str):
        self._set_status(msg)
        self._set_title(self._idle_icon())


def main():
    config.migrate_legacy_data_dir()
    ScribeMeApp().run()


if __name__ == "__main__":
    main()
