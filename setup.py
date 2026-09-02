"""py2app paketleme yapılandırması.

Kullanım (build.sh bunu sarar):
    .venv/bin/python setup.py py2app

Notlar:
- Whisper modeli (~1.6 GB) BUNDLE'A GÖMÜLMEZ — ilk açılışta indirilir
  (bkz. brain/Kararlar 2026-07-03 paketleme). .app küçük kalır.
- `packages` altındakiler klasörüyle kopyalanır — dylib/veri dosyaları
  (pywhispercpp/.dylibs, _sounddevice_data/portaudio-binaries) böylece taşınır.
- LSUIElement: menü barı uygulaması — Dock'ta ikon çıkmaz.
- NSMicrophoneUsageDescription şart: plist'te yoksa macOS mikrofon iznini
  sormaz, uygulamayı doğrudan öldürür.
"""

from setuptools import setup

APP = ["run.py"]

PLIST = {
    "CFBundleName": "Listender",
    "CFBundleDisplayName": "Listender",
    "CFBundleIdentifier": "com.uveyscolak.listender",
    "CFBundleShortVersionString": "2.0.0",
    "CFBundleVersion": "2.0.0",
    "LSUIElement": True,  # menü barı uygulaması: Dock ikonu yok
    "LSMinimumSystemVersion": "13.0",
    # Finder'dan açılan uygulamada yerel C/ASCII'dir — Türkçe karakterli
    # print/açılan dosyalar UnicodeEncodeError üretir (canlıda yaşandı,
    # 2026-07-03: dikte worker'ı sessizce ölüyordu). UTF-8 modunu zorla:
    "LSEnvironment": {"PYTHONUTF8": "1"},
    "NSMicrophoneUsageDescription": (
        "Listender, bas-konuş dikte için mikrofonunuzu dinler. "
        "Ses hiçbir zaman bu bilgisayardan çıkmaz."
    ),
    "NSHumanReadableCopyright": "© 2026 Üveys Çolak — tamamen yerel dikte",
}

OPTIONS = {
    "plist": PLIST,
    # Klasörüyle kopyalanacak paketler (dylib/veri dosyaları dahil):
    "packages": [
        "listender",
        "pywhispercpp",      # .dylibs/ (libwhisper, libggml-metal…) içinde
        "_sounddevice_data",  # portaudio-binaries/libportaudio.dylib içinde
        "rumps",
        "pynput",
        "numpy",
        "cffi",              # sounddevice'ın C köprüsü
    ],
    # Tek dosyalık modüller / dinamik importlar:
    "includes": [
        "sounddevice",
        "_cffi_backend",
    ],
    # Şişkinlik önleme — kullanılmayan büyük şeyler:
    "excludes": [
        "tkinter",
        "test",
        "unittest",
        "pydoc_data",
        "setuptools",
        "pip",
        "wheel",
    ],
}

setup(
    name="Listender",
    app=APP,
    options={"py2app": OPTIONS},
    setup_requires=["py2app"],
)
