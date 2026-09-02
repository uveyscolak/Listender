#!/bin/bash
# Release binary'sini /Applications/Listender.app paketine sarar.
# Kullanım: ./scripts/make-app.sh   (önce: swift build -c release)
#
# Bağımlılıkların kaynak paketleri (.bundle) BİLEREK kopyalanmıyor.
# Derleme çıktısında iki tane var (swift-crypto: yalnız gizlilik bildirimi,
# swift-transformers: kullanılmayan gpt2/t5 tokenizer yedekleri). Bunları .app
# köküne koymak imzayı geçersiz kılıyor ("unsealed contents present in the
# bundle root"), Contents/Resources'a koymak ise işe yaramıyor çünkü SwiftPM'in
# erişimcisi orayı hiç aramıyor. Deneyle doğrulandı: binary tek başına, yanında
# hiçbir paket yokken model yükleme ve transkript sorunsuz çalışıyor
# (`listender-ses-testi`). Bkz. brain/Kararlar 2026-09-02.
set -euo pipefail

cd "$(dirname "$0")/.."

BINARY=".build/release/Listender"
APP="/Applications/Listender.app"

if [ ! -f "$BINARY" ]; then
    echo "Önce derleyin: swift build -c release" >&2
    exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp "$BINARY" "$APP/Contents/MacOS/Listender"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Listender</string>
    <key>CFBundleIdentifier</key>
    <string>com.uveyscolak.listender</string>
    <key>CFBundleName</key>
    <string>Listender</string>
    <key>CFBundleDisplayName</key>
    <string>Listender</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>3.0.0</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Listender, bas-konuş dikte için mikrofonunuzu dinler. Ses hiçbir zaman bu bilgisayardan çıkmaz.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"

echo "Hazır: $APP"
echo "Başlatmak için: open $APP"
echo "İlk açılışta Giriş İzleme ve Erişilebilirlik izinlerini verin."
