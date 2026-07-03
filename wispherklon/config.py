"""Merkezi ayarlar ve sabitler."""

from pathlib import Path

# --- Model ---
# VidScribe'ın indirdiği dosya VARSA paylaşılır (bu makinede öyle); yoksa model
# Wispherklon'un kendi klasörüne indirilir — dağıtılan .app yabancı makinede
# "VidScribe" klasörü oluşturmasın.
MODEL_NAME = "large-v3-turbo"
MODEL_URL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-{name}.bin"

# Wispherklon kendi verisini burada tutar (model, log, ayar vb.)
APP_SUPPORT_DIR = Path.home() / "Library" / "Application Support" / "Wispherklon"
MODELS_DIR = APP_SUPPORT_DIR / "models"
VIDSCRIBE_MODELS_DIR = Path.home() / "Library" / "Application Support" / "VidScribe" / "models"

# --- Ses ---
SAMPLE_RATE = 16_000          # whisper.cpp'in beklediği örnekleme
CHANNELS = 1
DTYPE = "float32"
PRE_ROLL_SEC = 0.5            # tuşa basmadan önceki ses de dahil edilir
MAX_RECORD_SEC = 120          # bellek koruması; aşarsa eldeki ses işlenir
MIN_RECORD_SEC = 0.5          # bundan kısa basmalar transkript edilmez (halüsinasyon filtresi)

# --- Ses ön-işleme ---
# Kablosuz mikrofonun seviyesi çok düşük gelebiliyor (canlı test: konuşma RMS ~0.009).
# Transkript öncesi peak normalizasyon cılız sesi whisper'ın rahat çözdüğü seviyeye çeker.
NORMALIZE_PEAK = 0.95        # ses bu tepe değere ölçeklenir
SILENCE_RMS = 0.0002         # bunun altı "ses yok" sayılır — normalize/transkript edilmez
                             # (halüsinasyon önlemi; boş oda ~0.0003-0.0008 ölçüldü ama
                             # konuşma yoksa zaten transkript boş/halüsinasyon çıkar)

# --- Whisper ---
LANGUAGE = "tr"              # dil sabit, otomatik algılama yok
# Noktalama tutarlılığı hilesi: düzgün noktalamalı örnek cümle.
INITIAL_PROMPT = "Merhaba, bugün nasılsın? Umarım her şey yolundadır. Görüşmek üzere."

# --- Tetikleme ---
# Sağ Option (⌥) basılı tut / bırak. macOS'ta Key.alt_r.

# --- Temizlik ---
# Bağımsız token olarak her yerde silinecek dolgular:
FILLER_TOKENS = ["eee", "ee", "ıı", "hı", "hıı", "ııı", "ee"]
# Cümle başı / ardışık tekrarda temizlenecek yumuşak dolgular:
SOFT_FILLERS = ["yani", "hani", "şey", "işte", "falan"]

# Bilinen whisper halüsinasyon kalıpları (boş/sessiz seste üretilir):
HALLUCINATION_PATTERNS = [
    "altyazı m.k.",
    "altyazı mk",
    "abone ol",
    "izlediğiniz için teşekkür",
    "teşekkür ederim",  # yalnızca tek başına segmentse (temizleyicide kontrol edilir)
]

# --- Ollama (opsiyonel LLM temizliği) ---
# Model tarihi (bkz. Kararlar 2026-07-03):
# - qwen3:4b: thinking kapatılamıyor, 60+ sn — elendi.
# - qwen2.5:3b-instruct: hızlı ama anlamı ağır bozuyor (prompt sızıntısı,
#   Çince karakter, kişi kayması) — elendi.
# - qwen3:4b-instruct (thinking'siz): en iyisi — marka adlarını korur, ~0.6 sn.
#   ANCAK hâlâ kişi/eş-anlamlı kayması yapabiliyor ("verdim"→"verildi") →
#   varsayılan KAPALI; bilinçli kullanıcı menüden açar.
OLLAMA_URL = "http://127.0.0.1:11434"
OLLAMA_MODEL = "qwen3:4b-instruct"
# Finder'dan açılan .app'in PATH'inde /opt/homebrew/bin olmaz — binary buradan aranır:
OLLAMA_BINARY_PATHS = [
    "/opt/homebrew/bin/ollama",              # Homebrew (Apple Silicon)
    "/usr/local/bin/ollama",                 # Homebrew (Intel) / resmi installer
    "/Applications/Ollama.app/Contents/Resources/ollama",  # resmi .app
]
OLLAMA_DOWNLOAD_URL = "https://ollama.com/download"
OLLAMA_KEEP_ALIVE = "30m"        # modeli bellekte tut, cold-start'ı önle
OLLAMA_NUM_PREDICT = 256         # çıktı token sınırı (dikte metni kısa)
OLLAMA_ENABLED_DEFAULT = False
# Few-shot format: talimat-içi örnekler (eski yöntem) küçük modellerde çıktıya
# sızıyordu ("Görüştük..." vakası). Örnekler ayrı user/assistant mesajları
# olarak gönderilir — sızıntıyı büyük ölçüde kesiyor (test edildi, 2026-07-03).
LLM_SYSTEM_PROMPT = (
    "Türkçe dikte metnini düzelt: dolgu kelimelerini (eee, ıı, yani, hani, şey, "
    "işte, falan) sil, noktalama ve büyük harfleri düzelt. Kelimeleri, fiil "
    "çekimlerini ve zamanı AYNEN koru; kelime ekleme, çıkarma, eş anlamlısıyla "
    "değiştirme. Yabancı veya bilmediğin kelimeleri (marka, uygulama adı) aynen "
    "bırak. Sadece düzeltilmiş metni yaz."
)
LLM_FEWSHOT = [
    ("eee bugün müşteriyle görüştük yani sipariş onaylandı",
     "Bugün müşteriyle görüştük, sipariş onaylandı."),
    ("yarın ııı saat üçte şey toplantı var işte",
     "Yarın saat üçte toplantı var."),
    ("fiyat listesini ııı dün akşam güncelledim işte",
     "Fiyat listesini dün akşam güncelledim."),
    ("bu ürünün fiyatını hani beş yüz lira yapalım mı",
     "Bu ürünün fiyatını beş yüz lira yapalım mı?"),
]

# --- Enjeksiyon ---
PASTE_RESTORE_DELAY = 0.3    # Cmd-V sonrası eski panoyu geri yüklemeden önce beklenecek süre


def model_path() -> Path:
    """Kullanılacak model dosyası: VidScribe'ınki varsa o, yoksa kendi klasörümüz."""
    name = f"ggml-{MODEL_NAME}.bin"
    vidscribe = VIDSCRIBE_MODELS_DIR / name
    if vidscribe.exists():
        return vidscribe
    return MODELS_DIR / name
