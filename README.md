# ScribeMe

Wispr Flow'un tamamen yerel/offline Türkçe dikte klonu. macOS menü barında yaşar.
**Sağ Option (⌥)** tuşuna basılı tut → konuş → bırak. whisper.cpp sesi Türkçe'ye
çevirir, dolgular temizlenir, metin aktif uygulamanın imlecine yazılır. **Ses makineden çıkmaz.**

> Bu proje daha önce **Wispherklon** adıyla yayınlandı. v3.0.0 ile adı ScribeMe oldu;
> eski sürümden geçiyorsan aşağıdaki [Wispherklon'dan geçiş](#wispherklondan-geçiş)
> bölümünü oku.

## Kurulum

1. [Releases](https://github.com/uveyscolak/ScribeMe/releases) sayfasından
   **`ScribeMe-3.0.0.dmg`** dosyasını indir ve çift tıklayarak aç.
2. Açılan pencerede **`kur.command`** dosyasına **sağ tıkla → Aç** de, çıkan uyarıda
   yine **Aç**'a bas. (Çift tık yetmez: dosya internetten indiği için macOS ilk
   seferde durdurur. Sağ tık → Aç bunu aşar.)
3. Kurulum kendisi hallediyor: karantinayı kaldırır, uygulamayı **Uygulamalar**
   klasörüne taşır, izin panellerini açar ve ScribeMe'i başlatır.
4. Açılan panellerde aşağıdaki **izinleri** ver (bir kez) ve uygulamayı yeniden başlat.

> **Neden bu kadar uğraş?** Uygulama imzasız (Apple Developer hesabı yok — 99 $/yıl).
> macOS internetten inen imzasız uygulamaları karantinaya alır. Kod açık — ne
> çalıştığını [buradan](https://github.com/uveyscolak/ScribeMe) inceleyebilirsin.
>
> Elle kurmayı tercih edersen: DMG'deki `ScribeMe.app`'i **Applications** kısayoluna
> sürükle, sonra Terminal'de `xattr -dr com.apple.quarantine /Applications/ScribeMe.app`
> komutunu çalıştır.

Whisper modeli (`ggml-large-v3-turbo.bin`, ~1.5 GB) **ilk açılışta bir kez**
otomatik indirilir (menü barındaki durum satırında ilerlemeyi görürsün).
Sonrası tamamen offline çalışır.

## macOS İzinleri (ilk çalıştırmada bir kez)

**Sistem Ayarları → Gizlilik ve Güvenlik** — üçünde de listede **ScribeMe**'i işaretle
(listede yoksa `+` ile Uygulamalar'dan ekle). İzinlerden sonra uygulamayı yeniden başlat.

| İzin | Ne için | Nerede |
|---|---|---|
| **Mikrofon** | Sesi yakalamak | Gizlilik → Mikrofon (ilk kayıtta macOS kendisi sorar) |
| **Giriş İzleme** (Input Monitoring) | Sağ ⌥ tuşunu dinlemek | Gizlilik → Giriş İzleme |
| **Erişilebilirlik** (Accessibility) | Cmd-V ile metni yazmak | Gizlilik → Erişilebilirlik |

## Wispherklon'dan geçiş

ScribeMe, macOS'un gözünde **yepyeni bir uygulama** (bundle kimliği değişti).
Pratikte bunun iki sonucu var:

- **İzinleri bir kez daha vermen gerekiyor.** Mikrofon, Giriş İzleme ve
  Erişilebilirlik listelerinde eski `Wispherklon` satırlarını silip ScribeMe'i ekle.
- **Model yeniden inmez.** Uygulama ilk açılışta eski veri klasörünü
  (`~/Library/Application Support/Wispherklon`) yeni adına taşır, ~1.5 GB'lık model
  olduğu yerde kalır.

Eski `/Applications/Wispherklon.app` dosyasını çöpe atabilirsin.

## Opsiyonel — LLM temizliği (Ollama)

Noktalama/akıcılık düzeltmesi için yerel LLM. **Gerekli değil** — uygulama LLM'siz
de tam çalışır (regex temizliği her zaman açık). Menüden **LLM temizliği**'ne
tıkla: Ollama kurulu değilse indirme sayfasına yönlendirir, kuruluysa modeli
(~2.5 GB, bir kez) senin onayınla indirir. Her şey yerel — hiçbir veri dışarı çıkmaz.

## Menü

- **🎙️ boşta · 🔴 kayıt · ✍️ işleniyor · ⏳ yükleniyor · 🚫 mikrofon yok**
- **LLM temizliği (Ollama)** — aç/kapa
- **Çıkış**

## Geliştirici kurulumu (kaynaktan)

```bash
python3.14 -m venv .venv
.venv/bin/pip install -r requirements.txt
./ScribeMe.command             # çalıştır
```

İzin notu: kaynaktan çalıştırırken izinler launcher'ı başlatan uygulamaya
(genelde **Terminal**) bağlanır — hep `ScribeMe.command` üzerinden başlat.

### .app ve DMG build almak

```bash
.venv/bin/pip install -r requirements-build.txt
brew install create-dmg
./build.sh                     # dist/ScribeMe.app + dist/ScribeMe-<sürüm>.dmg
```

Build py2app ile alınır, ad-hoc imzalanır (`codesign -s -`), sonra DMG'ye paketlenir
(içinde `ScribeMe.app`, `kur.command` ve `Applications` kısayolu). Model bundle'a
gömülmez — .app ~75 MB kalır. Sürüm numarası tek yerden, `setup.py`'deki
`CFBundleShortVersionString` alanından okunur.

## Nasıl çalışır

`sounddevice` (16 kHz mono, ~0.5 sn pre-roll) → `pywhispercpp` large-v3-turbo (dil `tr`,
açılışta bir kez yüklenir, sıcak tutulur) → regex dolgu temizliği (+opsiyonel Ollama) →
`NSPasteboard` + Quartz Cmd-V enjeksiyon (eski pano geri yüklenir).

Detaylı hedef/karar/durum: [`brain/`](brain/).
