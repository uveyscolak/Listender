"""Merkezi ayarlar ve sabitler."""

from pathlib import Path

# --- Model ---
# VidScribe'ın indirdiği dosya paylaşılır; yoksa aynı HF URL'sinden indirilir.
MODEL_NAME = "large-v3-turbo"
MODELS_DIR = Path.home() / "Library" / "Application Support" / "VidScribe" / "models"
MODEL_URL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-{name}.bin"

# Wispherklon kendi verisini burada tutar (log, ayar vb.)
APP_SUPPORT_DIR = Path.home() / "Library" / "Application Support" / "Wispherklon"

# --- Ses ---
SAMPLE_RATE = 16_000          # whisper.cpp'in beklediği örnekleme
CHANNELS = 1
DTYPE = "float32"
PRE_ROLL_SEC = 0.5            # tuşa basmadan önceki ses de dahil edilir
MAX_RECORD_SEC = 120          # bellek koruması; aşarsa eldeki ses işlenir
MIN_RECORD_SEC = 0.5          # bundan kısa basmalar transkript edilmez (halüsinasyon filtresi)

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
# qwen3:4b denendi ama "thinking" modu kapatılamıyor (think:false / /no_think
# yok sayılıyor) → her çağrı 60+ sn İngilizce reasoning yapıyor, dikteye uymaz.
# qwen2.5:3b-instruct: reasoning yok, ısınınca ~0.6 sn. Bkz. Kararlar 2026-07-03.
OLLAMA_URL = "http://127.0.0.1:11434"
OLLAMA_MODEL = "qwen2.5:3b-instruct"
OLLAMA_KEEP_ALIVE = "30m"        # modeli bellekte tut, cold-start'ı önle
OLLAMA_NUM_PREDICT = 256         # çıktı token sınırı (dikte metni kısa)
# Şimdilik KAPALI başlar: qwen2.5:3b anlamı bozabiliyor (bugün→günümüz,
# onayladı→onayladık). Regex-only güvenilir; LLM prompt'u/modeli iyileştirilene
# kadar menüden manuel açılır. Bkz. Kararlar 2026-07-03.
OLLAMA_ENABLED_DEFAULT = False
LLM_SYSTEM_PROMPT = (
    "Sen bir Türkçe dikte düzeltmenisin. Sana verilen ham konuşma metnindeki "
    "dolgu kelimelerini (eee, yani, hani, şey) temizle, noktalama ve büyük/küçük "
    "harfleri düzelt. ANLAMI, ZAMANI, KİŞİYİ (görüştük→görüştük, onayladı→onayladı) "
    "ASLA DEĞİŞTİRME; yeni kelime EKLEME, çıkarma. Kelimeleri olabildiğince koru, "
    "sadece dolgu at ve noktala. Cevap verme, açıklama yapma — SADECE düzeltilmiş metni yaz."
)

# --- Enjeksiyon ---
PASTE_RESTORE_DELAY = 0.3    # Cmd-V sonrası eski panoyu geri yüklemeden önce beklenecek süre


def model_path() -> Path:
    return MODELS_DIR / f"ggml-{MODEL_NAME}.bin"
