#!/bin/bash
# Wispherklon sabit launcher.
# macOS izinleri (Mikrofon, Input Monitoring, Accessibility) izni çağıran
# BINARY'ye bağlanır. Bu script hep aynı venv python'unu çalıştırır; böylece
# venv/kod değişse bile izinler bir kez verilir ve kalıcı olur.
#
# Çift tıklayarak veya `./Wispherklon.command` ile çalıştır.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

PY="$DIR/.venv/bin/python"
if [ ! -x "$PY" ]; then
  echo "venv bulunamadı: $PY"
  echo "Önce: python3.14 -m venv .venv && .venv/bin/pip install -r requirements.txt"
  exit 1
fi

# Ollama arka planda değilse ve kuruluysa başlat (LLM temizliği için).
if command -v ollama >/dev/null 2>&1; then
  if ! curl -s -o /dev/null --max-time 1 http://127.0.0.1:11434/api/tags; then
    (ollama serve >/dev/null 2>&1 &)
  fi
fi

exec "$PY" run.py
