"""Ses yakalama — sounddevice InputStream + pre-roll ring buffer.

Mikrofon sürekli açık bir stream'de dinlenir; ses küçük bir ring buffer'da
(~pre-roll süresi) daima taze tutulur. Kayıt başlatılınca bu pre-roll tamponu
ilk parça olarak alınır (tuşa basmadan önceki ses de dahil — ilk hece yutulmaz),
sonrası kayıt bitene kadar biriktirilir.

Ses diske yazılmaz; float32 numpy dizisi olarak döner.
"""

import collections
import threading

import numpy as np
import sounddevice as sd

from . import config

# 30 ms bloklar — düşük gecikme, callback yükü makul.
_BLOCK = int(config.SAMPLE_RATE * 0.03)


class Recorder:
    def __init__(self):
        self._stream = None
        self._lock = threading.Lock()
        self._recording = False
        self._frames = []                       # kayıt sırasında biriken bloklar
        # pre-roll: son ~PRE_ROLL_SEC saniyeyi tutan ring buffer
        maxlen = max(1, int(config.PRE_ROLL_SEC * config.SAMPLE_RATE / _BLOCK))
        self._preroll = collections.deque(maxlen=maxlen)
        self._max_samples = config.MAX_RECORD_SEC * config.SAMPLE_RATE
        self._recorded_samples = 0
        self._on_limit = None                   # üst sınır aşılınca çağrılır

    def _callback(self, indata, frames, time_info, status):
        block = indata.copy().reshape(-1)       # (N,1) -> (N,)
        with self._lock:
            if self._recording:
                self._frames.append(block)
                self._recorded_samples += len(block)
                if self._recorded_samples >= self._max_samples and self._on_limit:
                    # ana thread'i bloklama; callback içinden sadece tetikle
                    limit_cb = self._on_limit
                    self._on_limit = None
                    threading.Thread(target=limit_cb, daemon=True).start()
            else:
                self._preroll.append(block)

    @staticmethod
    def refresh_devices():
        """PortAudio aygıt listesini tazele — sonradan takılan mikrofonu görmek için.

        sounddevice aygıtları ilk sorguda cache'ler; USB/Bluetooth mikrofon
        çalışırken bağlanınca yeniden başlatmadan görünmez. _terminate/_initialize
        bu cache'i sıfırlar.
        """
        try:
            sd._terminate()
            sd._initialize()
        except Exception:
            pass

    @staticmethod
    def has_input_device() -> bool:
        """Sistemde kullanılabilir bir giriş (mikrofon) aygıtı var mı?"""
        try:
            default_in = sd.default.device[0]
            if default_in is not None and default_in >= 0:
                return True
            # Varsayılan yoksa herhangi bir giriş kanallı aygıt ara.
            for dev in sd.query_devices():
                if dev.get("max_input_channels", 0) > 0:
                    return True
            return False
        except Exception:
            return False

    def is_streaming(self) -> bool:
        return self._stream is not None

    def start_stream(self):
        """Mikrofon stream'ini aç. Giriş aygıtı yoksa PortAudioError fırlatır."""
        if self._stream is not None:
            return
        self._stream = sd.InputStream(
            samplerate=config.SAMPLE_RATE,
            channels=config.CHANNELS,
            dtype=config.DTYPE,
            blocksize=_BLOCK,
            callback=self._callback,
        )
        self._stream.start()

    def stop_stream(self):
        if self._stream is not None:
            self._stream.stop()
            self._stream.close()
            self._stream = None

    def start_recording(self, on_limit=None):
        """Kaydı başlat. on_limit: üst sınır aşılınca çağrılacak (opsiyonel)."""
        with self._lock:
            if self._recording:
                return
            # pre-roll tamponunu ilk parça olarak al
            self._frames = list(self._preroll)
            self._recorded_samples = sum(len(f) for f in self._frames)
            self._recording = True
            self._on_limit = on_limit

    def stop_recording(self) -> np.ndarray:
        """Kaydı bitir ve biriken sesi tek float32 dizi olarak döndür."""
        with self._lock:
            self._recording = False
            self._on_limit = None
            frames = self._frames
            self._frames = []
            self._recorded_samples = 0
        if not frames:
            return np.zeros(0, dtype=np.float32)
        return np.concatenate(frames).astype(np.float32)
