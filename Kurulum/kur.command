#!/bin/bash
# Wispherklon tek-tık kurulum. Bu dosyaya ÇİFT TIKLA.
#
# Yaptıkları:
#   1. Karantinayı kaldırır (imzasız .app Gatekeeper duvarını aşar)
#   2. Wispherklon.app'i /Applications'a taşır
#   3. Giriş İzleme + Erişilebilirlik izin panellerini açar
#   4. Uygulamayı başlatır (ilk kayıtta mikrofon iznini macOS kendisi sorar)

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SRC="$DIR/Wispherklon.app"
APP_DST="/Applications/Wispherklon.app"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Wispherklon kurulumu"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

if [ ! -d "$APP_SRC" ]; then
  echo "✗ Wispherklon.app bulunamadı: $APP_SRC"
  echo "  kur.command ile Wispherklon.app aynı klasörde olmalı."
  read -n1 -r -p "Kapatmak için bir tuşa bas…"; exit 1
fi

# Çalışan örneği durdur (yeniden kurulumda)
pkill -f "Wispherklon.app" 2>/dev/null || true
sleep 1

echo "1/4  Karantina kaldırılıyor…"
xattr -dr com.apple.quarantine "$APP_SRC" 2>/dev/null || true

echo "2/4  /Applications klasörüne taşınıyor…"
rm -rf "$APP_DST"
ditto "$APP_SRC" "$APP_DST"
xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true

echo "3/4  İzin panelleri açılıyor…"
echo
echo "   ⚠️  Açılan pencerelerde listeye 'Wispherklon' ekle / işaretle:"
echo "        • Giriş İzleme  (sağ ⌥ tuşunu dinlemek için)"
echo "        • Erişilebilirlik  (metni imlece yazmak için)"
echo "        (Listede yoksa: + → Uygulamalar → Wispherklon)"
echo
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
sleep 2
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

echo "4/4  Uygulama başlatılıyor…"
echo "   (İlk kayıtta mikrofon izni sorulursa 'İzin Ver' de.)"
open "$APP_DST"

echo
echo "✅ Kuruldu. Menü barında 🎙️ ikonu belirir."
echo "   İzinleri verdikten sonra uygulamayı bir kez yeniden başlat"
echo "   (menüden Çıkış → Uygulamalar'dan Wispherklon)."
echo
echo "   Kullanım: herhangi bir yerde sağ ⌥ tuşuna BASILI TUT → konuş → BIRAK."
echo
read -n1 -r -p "Bu pencereyi kapatmak için bir tuşa bas…"
