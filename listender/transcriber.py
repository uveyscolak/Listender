"""Gömülü Whisper motoru — pywhispercpp (whisper.cpp + Metal).

Model uygulama açılışında BİR KEZ yüklenir ve bellekte sıcak tutulur
(VidScribe'daki her-çağrıda-yükleme deseni dikteye uymaz). Açılışta
kısa bir warm-up inference yapılır ki ilk gerçek dikte hızlı olsun.

Ses hiçbir zaman diske yazılmaz; numpy dizisi doğrudan motora verilir.
"""

import urllib.request

import numpy as np

from . import config


class Transcriber:
    def __init__(self, status_callback=None):
        self._status = status_callback or (lambda msg: None)
        self._model = None

    def _report(self, msg: str):
        self._status(msg)

    def _ensure_model(self):
        """Model diskte yoksa Hugging Face'ten indir (bir kez)."""
        path = config.model_path()
        if path.exists():
            return path
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".indiriliyor")
        url = config.MODEL_URL.format(name=config.MODEL_NAME)
        req = urllib.request.Request(url, headers={"User-Agent": "Listender"})
        with urllib.request.urlopen(req, timeout=30) as resp, open(tmp, "wb") as out:
            total = int(resp.headers.get("Content-Length") or 0)
            done = 0
            while True:
                chunk = resp.read(1024 * 512)
                if not chunk:
                    break
                out.write(chunk)
                done += len(chunk)
                if total:
                    self._report(f"Model indiriliyor (bir kez): %{done * 100 // total}")
        tmp.rename(path)
        return path

    def load(self):
        """Modeli belleğe yükle ve warm-up yap. Açılışta bir kez çağrılır."""
        model_file = self._ensure_model()
        self._report("Model yükleniyor…")
        from pywhispercpp.model import Model  # geç import: açılışı erken bloklamasın

        self._model = Model(
            str(model_file),
            print_progress=False,
            print_realtime=False,
            redirect_whispercpp_logs_to=None,
        )
        # Warm-up: 1 sn sessizlik çöz, Metal pipeline'ı ısıt.
        self._report("Isınıyor…")
        silence = np.zeros(config.SAMPLE_RATE, dtype=np.float32)
        try:
            self._model.transcribe(silence, language=config.LANGUAGE)
        except Exception:
            pass  # warm-up hatası kritik değil
        self._report("Hazır")

    def transcribe(self, audio: np.ndarray) -> str:
        """float32 mono 16kHz numpy dizisini Türkçe metne çevir."""
        if self._model is None:
            raise RuntimeError("Model henüz yüklenmedi (load() çağrılmalı).")

        audio = np.asarray(audio, dtype=np.float32).flatten()
        # Peak normalizasyon: kablosuz mikrofon çok kısık gelebiliyor (RMS ~0.009
        # ölçüldü); cılız sesi whisper'ın rahat çözdüğü seviyeye çek.
        peak = float(np.abs(audio).max()) if len(audio) else 0.0
        if peak > 0:
            audio = audio * (config.NORMALIZE_PEAK / peak)
        segments = self._model.transcribe(
            audio,
            language=config.LANGUAGE,
            initial_prompt=config.INITIAL_PROMPT,
        )
        return " ".join(s.text.strip() for s in segments if s.text.strip()).strip()
