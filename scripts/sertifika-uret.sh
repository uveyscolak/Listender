#!/bin/bash
# Listender için kendi kendine imzalı kod imzalama sertifikası üretir.
#
# Neden gerekli: ad-hoc imzada (`codesign --sign -`) imzanın "hangi koda ait
# olduğunu" tanımlayan kural doğrudan kodun özetine bağlanıyor. Kod her
# derlemede değişince özet de değişiyor ve macOS'un izin veritabanı (TCC)
# kaydı geçersizleşiyor — verdiğiniz Erişilebilirlik ve Giriş İzleme izinleri
# her yeni derlemede uçuyor. Sabit bir sertifikayla imzalandığında bu kural
# "sertifika + uygulama kimliği" biçimine dönüşüyor ve izinler yerinde kalıyor.
#
# Apple Developer hesabı ($99/yıl) gerekmez. Sertifika yalnız bu makinede
# geçerlidir ve yalnız bu uygulamayı imzalar; başka hiçbir şeyi etkilemez.
#
# Kullanım: ./scripts/sertifika-uret.sh

set -uo pipefail

KIMLIK="${LISTENDER_IMZA_KIMLIGI:-Listender Kod Imzalama}"
ANAHTARLIK="$HOME/Library/Keychains/login.keychain-db"

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
hata()  { printf "\n%s✗ %s%s\n\n" "$RED" "$1" "$RESET" >&2; exit 1; }

# --- Zaten var mı ------------------------------------------------------------

if security find-identity -v -p codesigning 2>/dev/null | grep -qF "$KIMLIK"; then
    tamam "Sertifika zaten var: $KIMLIK"
    bilgi "Yeniden üretmek gerekmiyor. Paketlemek için: ./scripts/make-app.sh"
    exit 0
fi

adim "Kod imzalama sertifikası üretiliyor"
bilgi "Adı: $KIMLIK"

command -v openssl >/dev/null 2>&1 || hata "openssl bulunamadı."

CALISMA=$(mktemp -d /tmp/listender-sertifika.XXXXXX) || hata "Geçici klasör açılamadı."
trap 'rm -rf "$CALISMA"' EXIT

# --- Sertifikayı üret --------------------------------------------------------
#
# extendedKeyUsage=codeSigning şart: codesign bu uzantısı olmayan sertifikayı
# kabul etmiyor. basicConstraints ve keyUsage de kritik işaretli olmalı.

cat > "$CALISMA/openssl.cnf" <<'CNF'
[ req ]
distinguished_name = dn
x509_extensions    = v3
prompt             = no

[ dn ]
CN = LISTENDER_CN_YERI

[ v3 ]
basicConstraints       = critical,CA:false
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,codeSigning
subjectKeyIdentifier   = hash
CNF

# CN'yi güvenli biçimde yerleştir (kullanıcı adı değiştirmiş olabilir).
python3 - "$CALISMA/openssl.cnf" "$KIMLIK" <<'PY'
import io, sys
yol, ad = sys.argv[1], sys.argv[2]
metin = io.open(yol, encoding="utf-8").read()
io.open(yol, "w", encoding="utf-8").write(metin.replace("LISTENDER_CN_YERI", ad))
PY

if ! openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -config "$CALISMA/openssl.cnf" \
        -keyout "$CALISMA/anahtar.pem" \
        -out "$CALISMA/sertifika.pem" >"$CALISMA/openssl.log" 2>&1; then
    tail -5 "$CALISMA/openssl.log" >&2
    hata "Sertifika üretilemedi."
fi
tamam "Sertifika üretildi (10 yıl geçerli)"

# .p12'ye topla. Boş parola: dosya birazdan silinecek geçici bir pakettir,
# sır burada değil, anahtarlıkta korunuyor.
if ! openssl pkcs12 -export \
        -inkey "$CALISMA/anahtar.pem" \
        -in "$CALISMA/sertifika.pem" \
        -name "$KIMLIK" \
        -passout pass: \
        -out "$CALISMA/paket.p12" >>"$CALISMA/openssl.log" 2>&1; then
    tail -5 "$CALISMA/openssl.log" >&2
    hata "Sertifika paketlenemedi."
fi

# --- Anahtarlığa al ----------------------------------------------------------
#
# Giriş (login) anahtarlığına yazıyoruz; o zaten açık olduğu için parola
# penceresi çıkmaz. Ayrı bir anahtarlık kurmak kilitli olacağı için pencere
# açtırıyordu — bilerek öyle yapmıyoruz.
#
# -T /usr/bin/codesign: codesign bu anahtarı sormadan kullanabilsin.

adim "Anahtarlığa ekleniyor"
if ! security import "$CALISMA/paket.p12" \
        -k "$ANAHTARLIK" \
        -P "" \
        -T /usr/bin/codesign \
        -T /usr/bin/security \
        >"$CALISMA/import.log" 2>&1; then
    tail -5 "$CALISMA/import.log" >&2
    hata "Sertifika anahtarlığa eklenemedi."
fi
tamam "Anahtarlığa eklendi"

# codesign'ın her imzada onay penceresi açmaması için erişim listesini ayarla.
# Başarısız olursa kurulum yine çalışır, sadece ilk imzada bir onay penceresi
# çıkabilir — bu yüzden hata sayılmıyor.
if security set-key-partition-list -S apple-tool:,apple:,codesign: \
        -k "" "$ANAHTARLIK" >/dev/null 2>&1; then
    tamam "codesign erişimi ayarlandı"
else
    uyari "codesign erişimi ayarlanamadı — ilk imzada onay penceresi çıkabilir."
fi

# --- Doğrula -----------------------------------------------------------------

adim "Doğrulanıyor"
if ! security find-identity -v -p codesigning 2>/dev/null | grep -qF "$KIMLIK"; then
    hata "Sertifika eklendi ama kod imzalama kimliği olarak görünmüyor."
fi
tamam "Kod imzalama kimliği hazır: $KIMLIK"

printf "
%s╭────────────────────────────────────────╮%s
%s│  Sertifika hazır                       │%s
%s╰────────────────────────────────────────╯%s

  Bundan sonra %s./scripts/make-app.sh%s bu sertifikayla imzalar.
  Uygulamayı yeniden derleyip kurduğunuzda verdiğiniz izinler korunur.

  %sÖnemli:%s izinleri ilk kez bu imzayla vermeniz gerekiyor. Daha önce
  ad-hoc imzalı sürüme izin verdiyseniz, Sistem Ayarları'nda Listender'ı
  listeden çıkarıp yeniden ekleyin.

" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" \
  "$BOLD" "$RESET" "$BOLD" "$RESET"
