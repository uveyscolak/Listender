# Wispherklon

Wispr Flow'un tamamen yerel/offline Türkçe dikte klonu. macOS menü barında yaşar.
**Sağ Option (⌥)** tuşuna basılı tut → konuş → bırak. whisper.cpp sesi Türkçe'ye
çevirir, dolgular temizlenir, metin aktif uygulamanın imlecine yazılır. **Ses makineden çıkmaz.**

## Kurulum (indirilen .app — önerilen)

> Repo klonluysa en kısası: [`Kurulum/kur.command`](Kurulum/kur.command) dosyasına
> **çift tıkla** — karantina + Uygulamalar'a taşıma + izin panellerini açma dahil
> her şeyi kendisi yapar. Aşağıdaki adımlar elle kurulum içindir.

1. [Releases](https://github.com/uveyscolak/Wispherklon/releases) sayfasından
   `Wispherklon.zip`'i indir ve aç, `Wispherklon.app`'i **Uygulamalar** klasörüne taşı.
2. Terminal'i aç (⌘-boşluk → "Terminal") ve şu **tek komutu** yapıştır:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Wispherklon.app
   ```

   > Neden? Uygulama imzasız (Apple Developer hesabı yok — 99 $/yıl). macOS,
   > internetten inen imzasız uygulamaları karantinaya alır; bu komut karantinayı
   > kaldırır. Kod açık — ne çalıştığını [buradan](https://github.com/uveyscolak/Wispherklon) inceleyebilirsin.

3. `Wispherklon.app`'i çift tıkla → menü barında ⏳ / 🎙️ ikonu belirir.
4. Aşağıdaki **izinleri** ver (bir kez) ve uygulamayı yeniden başlat.

Whisper modeli (`ggml-large-v3-turbo.bin`, ~1.5 GB) **ilk açılışta bir kez**
otomatik indirilir (menü barındaki durum satırında ilerlemeyi görürsün).
Sonrası tamamen offline çalışır.

## macOS İzinleri (ilk çalıştırmada bir kez)

**Sistem Ayarları → Gizlilik ve Güvenlik** — üçünde de listede **Wispherklon**'u işaretle
(listede yoksa `+` ile Uygulamalar'dan ekle). İzinlerden sonra uygulamayı yeniden başlat.

| İzin | Ne için | Nerede |
|---|---|---|
| **Mikrofon** | Sesi yakalamak | Gizlilik → Mikrofon (ilk kayıtta macOS kendisi sorar) |
| **Giriş İzleme** (Input Monitoring) | Sağ ⌥ tuşunu dinlemek | Gizlilik → Giriş İzleme |
| **Erişilebilirlik** (Accessibility) | Cmd-V ile metni yazmak | Gizlilik → Erişilebilirlik |

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
./Wispherklon.command          # çalıştır
```

İzin notu: kaynaktan çalıştırırken izinler launcher'ı başlatan uygulamaya
(genelde **Terminal**) bağlanır — hep `Wispherklon.command` üzerinden başlat.

### .app build almak

```bash
.venv/bin/pip install -r requirements-build.txt
./build.sh                     # dist/Wispherklon.app + dist/Wispherklon.zip
```

Build py2app ile alınır, ad-hoc imzalanır (`codesign -s -`). Model bundle'a
gömülmez — .app ~75 MB kalır.

## Nasıl çalışır

`sounddevice` (16 kHz mono, ~0.5 sn pre-roll) → `pywhispercpp` large-v3-turbo (dil `tr`,
açılışta bir kez yüklenir, sıcak tutulur) → regex dolgu temizliği (+opsiyonel Ollama) →
`NSPasteboard` + Quartz Cmd-V enjeksiyon (eski pano geri yüklenir).

Detaylı hedef/karar/durum: [`brain/`](brain/).
