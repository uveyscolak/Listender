#!/bin/bash
# Wispherklon .app build scripti — py2app + ad-hoc imza + dağıtım zip'i.
#
# Kullanım: ./build.sh
# Çıktı:   dist/Wispherklon.app  +  dist/Wispherklon.zip (GitHub release için)
#
# Ad-hoc imza (codesign -s -): Apple Developer sertifikası YOK (bilinçli karar,
# bkz. brain/Kararlar 2026-07-03 paketleme). İndiren kullanıcı Gatekeeper
# karantinasını tek komutla kaldırır (README'de yazılı):
#   xattr -dr com.apple.quarantine /Applications/Wispherklon.app
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

PY="$DIR/.venv/bin/python"
if [ ! -x "$PY" ]; then
  echo "venv bulunamadı: $PY"
  echo "Önce: python3.14 -m venv .venv && .venv/bin/pip install -r requirements.txt -r requirements-build.txt"
  exit 1
fi

echo "==> Eski build temizleniyor…"
rm -rf build dist

echo "==> py2app build…"
"$PY" setup.py py2app 2>&1 | tail -5

APP="dist/Wispherklon.app"
[ -d "$APP" ] || { echo "HATA: $APP üretilemedi"; exit 1; }

echo "==> Ad-hoc imza (codesign -s -)…"
# --force: py2app'in yarım imzalarını ez; --deep: gömülü dylib'ler dahil.
codesign --force --deep -s - "$APP"
codesign --verify --deep "$APP" && echo "    imza doğrulandı"

echo "==> Zip (GitHub release)…"
# ditto: macOS bundle'ları resource fork'larıyla doğru zipler (zip -r DEĞİL).
ditto -c -k --keepParent "$APP" dist/Wispherklon.zip

echo
echo "✅ TAMAM:"
du -sh "$APP" dist/Wispherklon.zip
echo
echo "Yerel test: open $APP"
