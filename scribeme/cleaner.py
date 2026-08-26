"""Metin temizlik katmanı — iki aşama.

1) Regex/kelime listesi (her zaman): dolgu token'ları sil, yumuşak dolguları
   cümle başı/ardışık tekrarda temizle, çift boşluk/virgül düzelt,
   halüsinasyon kalıplarını at.
2) Opsiyonel Ollama (qwen3:4b): noktalama/akıcılık düzeltmesi. Ollama
   erişilemezse veya kapalıysa sessizce regex-only sonucuna düşer.
"""

import json
import re
import shutil
import subprocess
import urllib.error
import urllib.request

from . import config


# --- Aşama 1: regex ---

def _strip_hallucinations(text: str) -> str:
    low = text.strip().lower()
    # Tüm metin tek bir halüsinasyon kalıbından ibaretse komple at.
    for pat in config.HALLUCINATION_PATTERNS:
        if low == pat or low.rstrip(".!?") == pat.rstrip(".!?"):
            return ""
    return text


def regex_clean(text: str) -> str:
    if not text or not text.strip():
        return ""

    text = _strip_hallucinations(text)
    if not text:
        return ""

    # Sert dolgu token'ları: nerede olursa olsun sil (kelime sınırıyla).
    for tok in config.FILLER_TOKENS:
        text = re.sub(rf"(?<!\w){re.escape(tok)}(?!\w)", " ", text, flags=re.IGNORECASE)

    # Yumuşak dolgular: yalnızca cümle başında veya ardışık tekrarda.
    for tok in config.SOFT_FILLERS:
        # cümle başı: metnin başı ya da . ! ? sonrası
        text = re.sub(
            rf"(^|[.!?]\s+){re.escape(tok)}\b[,\s]*",
            r"\1",
            text,
            flags=re.IGNORECASE,
        )
        # ardışık tekrar: "yani yani" -> "yani"
        text = re.sub(
            rf"\b({re.escape(tok)})(\s+\1\b)+",
            r"\1",
            text,
            flags=re.IGNORECASE,
        )

    # Boşluk/noktalama düzeltmeleri.
    text = re.sub(r"\s+", " ", text)               # çoklu boşluk
    text = re.sub(r"\s+([,.!?;:])", r"\1", text)    # noktalama öncesi boşluk
    text = re.sub(r",\s*,+", ",", text)             # çift virgül
    text = re.sub(r"^[\s,]+", "", text)             # baştaki boşluk/virgül
    return text.strip()


# --- Aşama 2: Ollama ---

def ollama_binary() -> str | None:
    """Ollama binary'sinin yolu, kurulu değilse None.

    Finder'dan açılan .app'in PATH'inde /opt/homebrew/bin olmaz —
    bilinen kurulum yolları elle denenir, sonra PATH'e bakılır.
    """
    for p in config.OLLAMA_BINARY_PATHS:
        if shutil.which(p):
            return p
    return shutil.which("ollama")


def ollama_serving() -> bool:
    """Ollama servisi ayakta mı? (Model şartı YOK — sadece API cevabı.)"""
    try:
        req = urllib.request.Request(f"{config.OLLAMA_URL}/api/tags")
        with urllib.request.urlopen(req, timeout=1.5):
            return True
    except Exception:
        return False


def start_ollama_if_installed():
    """Ollama kuruluysa ve servis ayakta değilse arka planda başlat.

    v1'de bu işi ScribeMe.command launcher'ı yapıyordu; .app'te
    launcher olmadığı için açılışta uygulama üstlenir. Kurulu değilse
    sessizce geçer — LLM zaten opsiyonel.
    """
    binary = ollama_binary()
    if binary is None or ollama_serving():
        return
    try:
        subprocess.Popen(
            [binary, "serve"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,  # uygulama kapanınca ollama'yı öldürme
        )
    except Exception:
        pass


def pull_model(progress_callback=None) -> bool:
    """Hedef modeli Ollama'ya indir (bloklar — worker thread'den çağır)."""
    binary = ollama_binary()
    if binary is None:
        return False
    report = progress_callback or (lambda msg: None)
    try:
        proc = subprocess.Popen(
            [binary, "pull", config.OLLAMA_MODEL],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",  # .app'te yerel ASCII olabilir — çökme yerine değiştir
        )
        for line in proc.stdout:
            line = line.strip()
            if line:
                report(f"Model indiriliyor: {line[:60]}")
        return proc.wait() == 0
    except Exception:
        return False


def ollama_available() -> bool:
    """Ollama çalışıyor ve hedef model yüklü mü?"""
    try:
        req = urllib.request.Request(f"{config.OLLAMA_URL}/api/tags")
        with urllib.request.urlopen(req, timeout=1.5) as resp:
            data = json.loads(resp.read())
        names = [m.get("name", "") for m in data.get("models", [])]
        base = config.OLLAMA_MODEL.split(":")[0]
        return any(n == config.OLLAMA_MODEL or n.startswith(base) for n in names)
    except Exception:
        return False


def _strip_think(text: str) -> str:
    """qwen3 <think>…</think> bloklarını at."""
    return re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL).strip()


def ollama_clean(text: str, timeout: float = 20.0) -> str:
    """Metni Ollama ile düzelt (chat endpoint). Hata olursa girdiyi aynen döndür."""
    if not text.strip():
        return text
    # Few-shot: örnekler ayrı user/assistant çiftleri olarak gönderilir —
    # talimat-içi örnek küçük modellerde çıktıya sızıyor (bkz. config).
    messages = [{"role": "system", "content": config.LLM_SYSTEM_PROMPT}]
    for sample_in, sample_out in config.LLM_FEWSHOT:
        messages.append({"role": "user", "content": sample_in})
        messages.append({"role": "assistant", "content": sample_out})
    messages.append({"role": "user", "content": text})
    payload = {
        "model": config.OLLAMA_MODEL,
        "messages": messages,
        "stream": False,
        "keep_alive": config.OLLAMA_KEEP_ALIVE,
        "options": {
            "temperature": 0.1,
            "num_predict": config.OLLAMA_NUM_PREDICT,
        },
    }
    try:
        req = urllib.request.Request(
            f"{config.OLLAMA_URL}/api/chat",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read())
        out = _strip_think(data.get("message", {}).get("content", "")).strip()
        return out or text
    except Exception:
        return text


def clean(text: str, use_llm: bool) -> str:
    """Tam temizlik hattı. use_llm True ve Ollama erişilebilirse LLM de uygular."""
    cleaned = regex_clean(text)
    if not cleaned:
        return ""
    if use_llm and ollama_available():
        cleaned = ollama_clean(cleaned)
    return cleaned.strip()
