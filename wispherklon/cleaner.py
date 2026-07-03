"""Metin temizlik katmanı — iki aşama.

1) Regex/kelime listesi (her zaman): dolgu token'ları sil, yumuşak dolguları
   cümle başı/ardışık tekrarda temizle, çift boşluk/virgül düzelt,
   halüsinasyon kalıplarını at.
2) Opsiyonel Ollama (qwen3:4b): noktalama/akıcılık düzeltmesi. Ollama
   erişilemezse veya kapalıysa sessizce regex-only sonucuna düşer.
"""

import json
import re
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
