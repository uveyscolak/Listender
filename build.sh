#!/bin/bash
# ScribeMe .app build scripti — py2app + ad-hoc imza + dağıtım DMG'si.
#
# Kullanım: ./build.sh
# Çıktı:   dist/ScribeMe.app  +  dist/ScribeMe-<sürüm>.dmg (GitHub release için)
#
# Ad-hoc imza (codesign -s -): Apple Developer sertifikası YOK (bilinçli karar,
# bkz. brain/Kararlar 2026-07-03 paketleme). Bu yüzden indirilen uygulama
# Gatekeeper karantinasına takılır — karantinayı DMG'nin içindeki kur.command
# kaldırır, indiren kullanıcı ona sağ tıklayıp "Aç" der (bkz. README).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

PY="$DIR/.venv/bin/python"
if [ ! -x "$PY" ]; then
  echo "venv bulunamadı: $PY"
  echo "Önce: python3.14 -m venv .venv && .venv/bin/pip install -r requirements.txt -r requirements-build.txt"
  exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "create-dmg bulunamadı. Önce: brew install create-dmg"
  exit 1
fi

# Sürüm tek kaynaktan okunur: setup.py'deki plist (ikiye bölünmesin).
VERSION="$("$PY" -c "import ast,sys; t=ast.parse(open('setup.py',encoding='utf-8').read()); \
print(next(v.value for n in ast.walk(t) if isinstance(n,ast.Dict) \
for k,v in zip(n.keys,n.values) \
if isinstance(k,ast.Constant) and k.value=='CFBundleShortVersionString'))")"
echo "==> Sürüm: $VERSION"

echo "==> Eski build temizleniyor…"
rm -rf build dist

echo "==> py2app build…"
"$PY" setup.py py2app 2>&1 | tail -5

APP="dist/ScribeMe.app"
[ -d "$APP" ] || { echo "HATA: $APP üretilemedi"; exit 1; }

echo "==> Ad-hoc imza (codesign -s -)…"
# --force: py2app'in yarım imzalarını ez; --deep: gömülü dylib'ler dahil.
codesign --force --deep -s - "$APP"
codesign --verify --deep "$APP" && echo "    imza doğrulandı"

echo "==> DMG içeriği hazırlanıyor…"
# Staging: DMG'de görünecek her şey. ditto (cp -R değil) — bundle'ın
# sembolik linkleri ve öznitelikleri bozulmasın.
STAGE="dist/dmg-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
ditto "$APP" "$STAGE/ScribeMe.app"
ditto Kurulum/kur.command "$STAGE/kur.command"
chmod +x "$STAGE/kur.command"

DMG="dist/ScribeMe-$VERSION.dmg"
echo "==> DMG oluşturuluyor: $DMG"
rm -f "$DMG"
# --no-internet-enable: Safari'nin "indirince otomatik aç" davranışı
# karantina/izin akışını karıştırıyor, kapalı kalsın.
create-dmg \
  --volname "ScribeMe" \
  --window-pos 200 120 \
  --window-size 660 420 \
  --icon-size 110 \
  --icon "kur.command" 150 180 \
  --icon "ScribeMe.app" 330 180 \
  --app-drop-link 510 180 \
  --no-internet-enable \
  "$DMG" "$STAGE"

rm -rf "$STAGE"

echo
echo "✅ TAMAM:"
du -sh "$APP" "$DMG"
echo
echo "Yerel test:"
echo "  open $DMG          # bağla, kur.command'a çift tıkla"
echo "  open $APP          # DMG'siz doğrudan çalıştır"
