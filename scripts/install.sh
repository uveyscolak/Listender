#!/bin/bash
# Listender — tek komutla kurulum.
#
# Kullanım:
#   curl -fsSL https://raw.githubusercontent.com/uveyscolak/Listender/main/scripts/install.sh | bash
#
# Ne yapar: Command Line Tools'u kontrol eder (yoksa kurdurur), kaynağı indirir,
# derler, metin temizlik hattını doğrular, /Applications/Listender.app olarak
# kurar ve izin panellerini açar.

set -uo pipefail

REPO_URL="https://github.com/uveyscolak/Listender.git"
APP_PATH="/Applications/Listender.app"
WORK_DIR=""

if [ -t 1 ]; then
    BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
    RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
    BOLD=""; GREEN=""; YELLOW=""; RED=""; DIM=""; RESET=""
fi

adim()  { printf "\n%s▸ %s%s\n" "$BOLD" "$1" "$RESET"; }
tamam() { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
bilgi() { printf "  %s%s%s\n" "$DIM" "$1" "$RESET"; }
uyari() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }

hata() {
    printf "\n%s✗ Kurulum tamamlanamadı%s\n  %s\n\n" "$RED" "$RESET" "$1" >&2
    printf "  Yardım için: https://github.com/uveyscolak/Listender/issues\n\n" >&2
    exit 1
}

temizle() { [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap temizle EXIT

printf "\n%s╭────────────────────────────────────────╮%s\n" "$BOLD" "$RESET"
printf "%s│  Listender — kurulum                   │%s\n" "$BOLD" "$RESET"
printf "%s│  Türkçe bas-konuş dikte, tamamen yerel │%s\n" "$BOLD" "$RESET"
printf "%s╰────────────────────────────────────────╯%s\n" "$BOLD" "$RESET"

# --- 1) Sistem ---------------------------------------------------------------

adim "Sistem kontrol ediliyor"
[ "$(uname)" = "Darwin" ] || hata "Listender yalnızca macOS'ta çalışır."

MACOS_VERSION=$(sw_vers -productVersion)
if [ "${MACOS_VERSION%%.*}" -lt 14 ]; then
    hata "macOS 14 (Sonoma) veya üzeri gerekiyor. Bu Mac'te macOS $MACOS_VERSION var."
fi
tamam "macOS $MACOS_VERSION"

if [ "$(uname -m)" != "arm64" ]; then
    uyari "Apple Silicon değil — model Neural Engine yerine CPU'da koşar, dikte yavaş olur."
fi

# --- 2) Command Line Tools ---------------------------------------------------

adim "Geliştirici araçları kontrol ediliyor"
if xcode-select -p >/dev/null 2>&1 && command -v swift >/dev/null 2>&1; then
    tamam "Command Line Tools kurulu"
else
    uyari "Command Line Tools kurulu değil — Apple'ın kurulum penceresi açılacak."
    bilgi "Açılan pencerede 'Yükle' deyin (birkaç GB, 5-15 dakika)."
    xcode-select --install >/dev/null 2>&1 || true
    printf "\n  Bekleniyor"
    BEKLENEN=0
    while ! (xcode-select -p >/dev/null 2>&1 && command -v swift >/dev/null 2>&1); do
        sleep 10; BEKLENEN=$((BEKLENEN + 10)); printf "."
        [ "$BEKLENEN" -ge 1800 ] && { printf "\n"; hata "Kurulum 30 dakikada bitmedi."; }
    done
    printf "\n"; tamam "Command Line Tools kuruldu"
fi

# --- 3) Kaynak ---------------------------------------------------------------
# Script zaten klonlanmış bir kopyanın içinden çalıştırılırsa yeniden indirmez.

KAYNAK_KOK="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$KAYNAK_KOK/Package.swift" ]; then
    adim "Listender hazırlanıyor"
    cd "$KAYNAK_KOK" || hata "Kaynak klasörüne girilemedi."
    WORK_DIR=$(mktemp -d /tmp/listender-log.XXXXXX)
    tamam "Kaynak yerel kopyada"
else
    adim "Listender indiriliyor"
    WORK_DIR=$(mktemp -d /tmp/listender-kurulum.XXXXXX) || hata "Geçici klasör oluşturulamadı."
    if ! git clone --depth 1 "$REPO_URL" "$WORK_DIR/Listender" >/dev/null 2>&1; then
        hata "Kaynak indirilemedi. İnternet bağlantınızı kontrol edip tekrar deneyin."
    fi
    tamam "Kaynak indirildi"
    cd "$WORK_DIR/Listender" || hata "Kaynak klasörüne girilemedi."
fi

# --- 4) Derle ----------------------------------------------------------------

adim "Derleniyor"
bilgi "WhisperKit ve bağımlılıkları çekilecek — ilk seferde 2-5 dakika."
export LISTENDER_DIST=1   # test bağımlılığı çekilmesin

if ! swift build -c release > "$WORK_DIR/build.log" 2>&1; then
    printf "\n%s Derleme çıktısının son satırları:%s\n" "$DIM" "$RESET" >&2
    tail -20 "$WORK_DIR/build.log" >&2
    hata "Derleme başarısız oldu."
fi
tamam "Derleme tamam"

# --- 5) Doğrula --------------------------------------------------------------

adim "Metin temizleme hattı doğrulanıyor"
SMOKE=$(.build/release/Listender listender-temizlik-smoke 2>&1)
[ "$SMOKE" = "SMOKE OK" ] || hata "Temizlik testi geçmedi: $SMOKE"
tamam "Dolgu temizliği, noktalama ve halüsinasyon filtresi çalışıyor"

# --- 6) İmza sertifikası -----------------------------------------------------
# Sabit bir imza olmadan macOS, her yeni derlemeyi başka bir uygulama sayıp
# verilen izinleri siliyor. Sertifika bu makinede üretilir, dışarı çıkmaz.
# Üretilemezse kurulum durmaz; uygulama ad-hoc imzayla da çalışır, yalnız
# izinler yeniden derlemede sıfırlanabilir.

adim "İmza sertifikası hazırlanıyor"
IMZA_KIMLIGI="${LISTENDER_IMZA_KIMLIGI:-Listender Kod Imzalama}"
SERTIFIKA_VAR=0
if security find-identity -p codesigning 2>/dev/null | grep -qF "$IMZA_KIMLIGI"; then
    tamam "Sertifika zaten var — izinler derlemeler arası korunur"
    SERTIFIKA_VAR=1
elif ./scripts/sertifika-uret.sh >"$WORK_DIR/sertifika.log" 2>&1; then
    tamam "Sertifika üretildi — izinler derlemeler arası korunur"
    SERTIFIKA_VAR=1
else
    uyari "Sertifika üretilemedi, ad-hoc imzayla devam ediliyor."
    bilgi "Uygulama çalışır; ancak yeniden derlerseniz izinleri tekrar vermeniz gerekebilir."
    HATA_LOG="$HOME/Library/Logs/Listender/sertifika-hata.log"
    mkdir -p "$(dirname "$HATA_LOG")"
    cp "$WORK_DIR/sertifika.log" "$HATA_LOG" 2>/dev/null || true
    bilgi "Ayrıntı: $HATA_LOG"
fi

# Eski kurulumun imzasını oku: imza değişince macOS'un izin defteri (TCC)
# eski kaydı yeniyle eşleştiremiyor, anahtar açık görünür ama izin geçmiyor.
# Not: Authority= satırı yalnız -vvv (çok ayrıntılı) çıktıda görünüyor; tek -v
# bunu vermiyor, denenip doğrulandı. Ad-hoc imzada bu satır hiç yok.
ESKI_IMZA=""
if [ -d "$APP_PATH" ]; then
    ESKI_IMZA_SATIRI=$(codesign -dvvv "$APP_PATH" 2>&1 | grep '^Authority=' | head -1)
    if [ -n "$ESKI_IMZA_SATIRI" ]; then
        ESKI_IMZA="${ESKI_IMZA_SATIRI#Authority=}"
    else
        ESKI_IMZA="adhoc"
    fi
fi

if [ "$SERTIFIKA_VAR" = "1" ]; then
    YENI_IMZA="$IMZA_KIMLIGI"
else
    YENI_IMZA="adhoc"
fi

# Ad-hoc imza her derlemede değişir: eski ve yeni ikisi de ad-hoc olsa bile
# izin kaydı geçersizleşir. Yalnız aynı sertifikayla imzalanmışsa değişmemiştir.
IMZA_DEGISTI=0
if [ -d "$APP_PATH" ]; then
    if [ "$YENI_IMZA" = "adhoc" ] || [ "$ESKI_IMZA" != "$YENI_IMZA" ]; then
        IMZA_DEGISTI=1
    fi
fi

# --- 7) Kur ------------------------------------------------------------------

adim "Uygulama kuruluyor"
if [ -d "$APP_PATH" ]; then
    bilgi "Önceki sürüm kapatılıyor…"
    osascript -e 'tell application "Listender" to quit' >/dev/null 2>&1 || true
    pkill -x Listender >/dev/null 2>&1 || true
    sleep 1
fi
./scripts/make-app.sh >/dev/null 2>&1 || hata "Uygulama /Applications klasörüne kurulamadı."
[ -d "$APP_PATH" ] || hata "Uygulama beklenen yerde oluşmadı: $APP_PATH"
tamam "Kuruldu: $APP_PATH"

if [ "$IMZA_DEGISTI" = "1" ]; then
    tccutil reset Accessibility com.uveyscolak.listender >/dev/null 2>&1 || true
    tccutil reset ListenEvent com.uveyscolak.listender >/dev/null 2>&1 || true
    uyari "İmza değişti — eski izin kayıtları sıfırlandı, Giriş İzleme ve Erişilebilirlik'i yeniden vermeniz gerekecek."
fi

# --- 8) Başlat ve izinler ----------------------------------------------------

adim "Listender başlatılıyor"
open "$APP_PATH" || hata "Uygulama başlatılamadı."
tamam "Menü çubuğunda mikrofon ikonu belirecek"

adim "Son adım: izinler"
printf "
  Listender'ın çalışması için %süç izin%s gerekiyor:

    1. %sGiriş İzleme%s     — sağ ⌥ tuşunu duyabilmek için
    2. %sErişilebilirlik%s  — metni imlecin olduğu yere yazabilmek için
    3. %sMikrofon%s         — ilk kayıtta macOS kendisi soracak

  Uygulama açılınca Giriş İzleme ve Erişilebilirlik için macOS kendisi
  soracak; \"Sistem Ayarları'nı Aç\" deyip listede %sListender%s'ı açın.
  Sormazsa menü çubuğundaki Listender ▸ İzinler'den açabilirsiniz.
  Listede Listender yoksa \"+\" ile /Applications/Listender.app dosyasını ekleyin.
" "$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET"

sleep 3
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" 2>/dev/null || true

printf "
%s╭────────────────────────────────────────╮%s
%s│  Kurulum tamamlandı                    │%s
%s╰────────────────────────────────────────╯%s

  %sİlk açılış:%s Whisper modeli inecek (~1,5 GB) ve macOS onu bu uygulama için
  bir kez derleyecek (~2 dakika). Menü çubuğundaki durum bunu gösterir.
  Sonraki açılışlar birkaç saniye.

  %sKullanım:%s herhangi bir uygulamada sağ ⌥ tuşuna %sbasılı tut%s, konuş, %sbırak%s.
  Metin imlecin olduğu yere yazılır. Ses bilgisayardan hiç çıkmaz.

  İzinleri verdikten sonra menü çubuğundaki ikon 🎙️ olunca hazırdır.

" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" \
  "$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET"
