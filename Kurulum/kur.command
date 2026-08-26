#!/bin/bash
# ScribeMe tek-tık kurulum. Bu dosyaya SAĞ TIKLA → "Aç" de.
#
# (Çift tık yetmez: dosya internetten indiği için macOS ilk seferde
#  "bilinmeyen geliştirici" diye durdurur; sağ tık → Aç bunu aşar.)
#
# Yaptıkları:
#   1. Karantinayı kaldırır (imzasız .app Gatekeeper duvarını aşar)
#   2. ScribeMe.app'i /Applications'a taşır
#   3. Giriş İzleme + Erişilebilirlik izin panellerini açar
#   4. Uygulamayı başlatır (ilk kayıtta mikrofon iznini macOS kendisi sorar)

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SRC="$DIR/ScribeMe.app"
APP_DST="/Applications/ScribeMe.app"
LEGACY_APP="/Applications/Wispherklon.app"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   ScribeMe kurulumu"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

if [ ! -d "$APP_SRC" ]; then
  echo "✗ ScribeMe.app bulunamadı: $APP_SRC"
  echo "  kur.command ile ScribeMe.app aynı klasörde olmalı."
  read -n1 -r -p "Kapatmak için bir tuşa bas…"; exit 1
fi

# Çalışan örneği durdur (yeniden kurulumda). Eski adı da durdur: ikisi
# birden menü barında dururken hangisinin dinlediği karışıyor.
pkill -f "ScribeMe.app" 2>/dev/null || true
pkill -f "Wispherklon.app" 2>/dev/null || true
sleep 1

echo "1/4  Karantina kaldırılıyor…"
# DMG salt-okunur: kaynaktaki deneme başarısız olabilir, hedefte tekrar edilir.
xattr -dr com.apple.quarantine "$APP_SRC" 2>/dev/null || true

echo "2/4  /Applications klasörüne taşınıyor…"
rm -rf "$APP_DST"
ditto "$APP_SRC" "$APP_DST"
xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true

echo "3/4  İzin panelleri açılıyor…"
echo
echo "   ⚠️  Açılan pencerelerde listeye 'ScribeMe' ekle / işaretle:"
echo "        • Giriş İzleme  (sağ ⌥ tuşunu dinlemek için)"
echo "        • Erişilebilirlik  (metni imlece yazmak için)"
echo "        (Listede yoksa: + → Uygulamalar → ScribeMe)"
if [ -d "$LEGACY_APP" ]; then
  echo
  echo "   ℹ️  Eskiden Wispherklon kuruluymuş. ScribeMe macOS için YENİ bir"
  echo "      uygulama, izinleri devralmaz — bu yüzden yeniden veriyorsun."
  echo "      Listelerdeki eski 'Wispherklon' satırlarını silebilir,"
  echo "      $LEGACY_APP dosyasını da çöpe atabilirsin."
fi
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
echo "   (menüden Çıkış → Uygulamalar'dan ScribeMe)."
echo
echo "   Kullanım: herhangi bir yerde sağ ⌥ tuşuna BASILI TUT → konuş → BIRAK."
echo
read -n1 -r -p "Bu pencereyi kapatmak için bir tuşa bas…"
