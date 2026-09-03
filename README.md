# Listender

Wispr Flow'un tamamen yerel Türkçe dikte klonu. macOS menü çubuğunda yaşar.
**Sağ Option (⌥)** tuşuna basılı tut, konuş, bırak — söylediğin metin aktif
uygulamanın imlecine yazılır. **Ses bilgisayardan hiç çıkmaz**, internet gerekmez.

Native Swift uygulaması. Whisper large-v3-turbo modelini WhisperKit üzerinden
Apple Silicon'ın Neural Engine'inde koşturur.

## Gereksinimler

- macOS 14 (Sonoma) veya üzeri
- Apple Silicon önerilir (Intel'de model CPU'da koşar, dikte yavaşlar)
- Xcode gerekmez; kurulum script'i Command Line Tools'u gerekirse kendi kurar

## Kurulum

Terminal'i açın, şunu yapıştırıp Enter'a basın, birkaç dakika bekleyin:

```bash
curl -fsSL https://raw.githubusercontent.com/uveyscolak/Listender/main/scripts/install.sh | bash
```

Hiçbir dosya indirmezsiniz, hiçbir uyarı çıkmaz. Kaynak kendi makinenizde
derlenir, `/Applications/Listender.app` olarak kurulur. İmzasız bir uygulama
indirmediğiniz için Gatekeeper uyarısı çıkmaz.

## İzinler (bir kez)

Sistem Ayarları, Gizlilik ve Güvenlik altında üçü de gerekli:

| İzin | Ne için |
|---|---|
| **Giriş İzleme** | Sağ ⌥ tuşunu duymak |
| **Erişilebilirlik** | Metni imlecin olduğu yere yazmak |
| **Mikrofon** | Sesi yakalamak (ilk kayıtta macOS kendisi sorar) |

Erişilebilirlik izni yoksa metin **kaybolmaz**: panoda bırakılır, Cmd-V ile
kendin yapıştırabilirsin. Menü çubuğundaki durum satırı bunu söyler.

## İlk açılış

İki tek seferlik bekleme var:

1. Whisper modeli iner (~1,5 GB)
2. macOS modeli bu uygulama için derler (~2 dakika)

Sonraki açılışlarda model yüklemesi birkaç saniye sürer. Durum menü çubuğunda görünür.

## Kullanım

Menü çubuğundaki ikon durumu gösterir:

| İkon | Anlamı |
|---|---|
| 🎙️ | Hazır — sağ ⌥ ile bas-konuş |
| 🔴 | Kayıt sürüyor |
| ✍️ | Yazıya çevriliyor |
| ⏳ | Model hazırlanıyor |
| 🚫 | Mikrofon yok |

Yarım saniyeden kısa basmalar yok sayılır (yanlışlıkla basma filtresi). Tuşa
basmadan önceki yarım saniye de kayda girer, böylece ilk hece yutulmaz.

## Metin temizliği

Transkript ham haliyle yazılmaz, iki aşamadan geçer:

1. **Regex** (her zaman): "eee/ıı" gibi dolgular silinir; "yani/hani/şey/işte"
   yalnızca cümle başında ve ardışık tekrarda temizlenir — cümle ortasında gerçek
   anlam taşıyabildikleri için korunurlar. Boşluk ve noktalama düzeltilir.
   Whisper'ın sessizlikte uydurduğu bilinen kalıplar ("Altyazı M.K.", "abone ol")
   atılır.
2. **Ollama** (opsiyonel, varsayılan kapalı): menüden açılır, noktalama ve
   akıcılığı düzeltir. Kurulu değilse uygulama tam çalışır.

LLM varsayılan kapalı, çünkü denenen 4B sınıfı modeller hâlâ kişi kayması
yapabiliyor ("verdim" yerine "verildi"). Bilinçli olarak açılır.

## Geliştirme

```bash
swift build -c release
swift test                                              # 25 test, 9 suite
.build/release/Listender listender-temizlik-smoke       # temizlik hattı
.build/release/Listender listender-ses-testi ses.wav    # model + transkript
./scripts/make-app.sh                                   # /Applications'a paketle
```

Yapı: bütün mantık `Sources/ListenderKit/` içinde (test edilebilir kütüphane),
`Sources/Listender/main.swift` yalnız giriş noktası.

Türkçe test sesi üretmek için:

```bash
say -v Yelda -o ses.wav --data-format=LEF32@16000 "Bugün müşteriyle görüştük."
```

## Nasıl çalışır

`AVAudioEngine` (donanım örneklemesinden 16 kHz mono'ya dönüştürülür, ~0,5 sn
pre-roll halka tamponu) → WhisperKit large-v3-turbo (dil `tr` sabit, model
açılışta bir kez yüklenip sıcak tutulur) → regex temizliği (artı opsiyonel
Ollama) → `NSPasteboard` ve Cmd-V enjeksiyonu (eski pano geri yüklenir).

Ses hiçbir aşamada diske yazılmaz.

## Bilinen sınırlar

- İlk açılıştaki CoreML derlemesi her yeniden kurulumda tekrarlanır.
- Ad-hoc imza: uygulama yeniden derlendiğinde imza değiştiği için macOS
  izinleri sıfırlayabilir.
- Ölçüm (M2 Pro): 6 saniyelik ses 0,8 saniyede çözülüyor; model yüklemesi
  ilk açılışta ~135 sn, sonrasında ~7 sn.
