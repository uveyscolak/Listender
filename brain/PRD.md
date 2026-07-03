# WISPHERKLON — PRD

**Yazıldı:** 2026-07-03 · **Mod:** hızlı · **Bağlı:** [[Context]]

## Problem

macOS'un yerleşik diktesi Türkçe'de isabetsiz, noktalama üretmiyor ve "eee/yani/hani" gibi dolgu kelimeleri metne aynen geçiyor. Wispr Flow bu deneyimi çözüyor ama tamamen bulut tabanlı: ses makineden çıkıyor, abonelik gerektiriyor ve internetsiz çalışmıyor. Kullanıcı, herhangi bir uygulamada yazı yazarken klavye yerine konuşarak — hızlı, isabetli ve tamamen yerel — metin girmek istiyor.

## Çözüm

Wispr Flow akışının tamamen yerel/offline klonu — macOS menü barı uygulaması:

1. Kullanıcı **sağ Option (⌥)** tuşunu basılı tutar → mikrofon kaydı başlar (menü barı ikonu 🔴 olur).
2. Tuşu bırakır → kayıt biter, bellekte tutulan **whisper.cpp large-v3-turbo** modeli sesi Türkçe transkript eder (dil sabit `tr`, otomatik algılama yok).
3. Metin temizlenir: regex ile dolgu kelimeleri silinir; Ollama açıksa **Qwen3 4B** ile noktalama/akıcılık düzeltmesi yapılır (Ollama kapalıysa sessizce regex-only'ye düşer).
4. Temiz metin **pano + Cmd-V simülasyonu** ile o an aktif uygulamanın imleç konumuna yazılır; eski pano içeriği geri yüklenir.

Ses hiçbir zaman makineden çıkmaz. Hedef gecikme: tuş bırakımından metnin yazılmasına 1–2 sn (LLM katmanı açıkken +0.5–1 sn).

## Uygulama Kararları

- **Dil/stack:** Python 3 — mevcut VidScribe motoru (`pywhispercpp`) ile uyum. Referans mimari: `savbell/whisper-writer` (sounddevice → whisper → pynput zinciri).
- **STT:** `pywhispercpp` (whisper.cpp + Metal). Model **large-v3-turbo**, VidScribe'ın indirdiği dosya paylaşılır (`~/Library/Application Support/VidScribe/models/ggml-large-v3-turbo.bin`); yoksa aynı Hugging Face URL'sinden indirilir. Model **uygulama açılışında bir kez yüklenir, bellekte sıcak tutulur** (VidScribe'daki her-çağrıda-yükleme deseni dikteye uymaz). Açılışta warm-up inference yapılır.
- **Ses yakalama:** `sounddevice` InputStream, 16 kHz mono float32, callback → ring buffer. ~0.5 sn **pre-roll** tamponu (tuşa basmadan önceki ses de dahil edilir — ilk hece yutulmaz). Ses diske yazılmaz, numpy dizisi doğrudan motora verilir.
- **Tetikleme:** bas-konuş — **sağ Option** basılı tut / bırak. `pynput` global listener; VAD gerekmez (tuş = sınır).
- **Metin enjeksiyonu:** `NSPasteboard` içeriği kaydet → metni koy → Quartz `CGEventPost` ile Cmd-V → ~300 ms bekle → eski panoyu geri yükle. (Karakter karakter klavye simülasyonu macOS'ta Türkçe karakterlerde güvenilmez — elenmiştir.)
- **Temizlik katmanı:** (1) regex/kelime listesi: bağımsız token olarak `eee, ıı, hı, ee` + cümle başı/ardışık tekrar durumunda `yani, hani, şey, işte, falan`; çift boşluk/virgül düzeltme. (2) Opsiyonel: Ollama `qwen3:4b` — "dolguları temizle, noktalamayı düzelt, anlamı DEĞİŞTİRME" promptu. Ollama erişilemezse otomatik regex-only.
- **Halüsinasyon filtresi:** kayıt < 0.5 sn ise transkript çağrılmaz; bilinen halüsinasyon kalıpları ("Altyazı M.K." vb.) ve boş segmentler atılır.
- **UI:** `rumps` menü barı uygulaması — durum ikonu (boşta / 🔴 kayıt / ⏳ işleniyor), LLM temizlik aç/kapa, çıkış. Ağır işler worker thread'de (rumps ana thread'i kilitler).
- **İzin stratejisi:** Mikrofon + Input Monitoring + Accessibility izinleri **sabit bir launcher** üzerinden hep aynı binary'ye verilir (macOS izni çağıran binary'ye bağlar; venv değişince bozulma tuzağına karşı). Kurulumda izin rehberi gösterilir.
- **Whisper ayarı:** `language="tr"` sabit; `initial_prompt` ile düzgün noktalamalı Türkçe örnek cümle verilir (noktalama tutarlılığı hilesi).

## Kabul Kriterleri

- [ ] Menü barı uygulaması açılır; model açılışta bir kez yüklenir, ikon durumu yansıtır.
- [ ] Herhangi bir uygulamada (Notlar, Safari, VS Code) sağ Option basılı tutup konuşunca, tuş bırakıldıktan sonra metin imleç konumuna yazılır.
- [ ] Transkript Türkçe karakterlerle (ğüşıöçİ) sorunsuz yazılır; eski pano içeriği geri yüklenir.
- [ ] Regex temizliği çalışır: "eee bugün yani toplantı vardı" → dolgular temizlenmiş halde yazılır.
- [ ] Ollama + qwen3:4b açıkken LLM temizliği devreye girer; Ollama kapatılınca uygulama hatasız regex-only çalışır.
- [ ] 5–10 sn'lik dikte, tuş bırakımından itibaren ≤2 sn'de yazılır (LLM kapalı, M4).
- [ ] < 0.5 sn'lik yanlışlıkla basmalarda hiçbir şey yazılmaz (halüsinasyon filtresi).
- [ ] Uygulama internetsiz (Wi-Fi kapalı) uçtan uca çalışır — model diskte hazırken.

## Kapsam Dışı

- Toggle / hands-free mod ve VAD ile konuşma sonu tespiti (v2 adayı).
- Streaming (konuşurken canlı yazma) — kayıt-sonu transkript bilinçli tercih.
- Uygulama bağlamına göre ton/format değiştirme (Wispr'ın "app context" özelliği).
- Türkçe dışında dil, dil algılama.
- Kişisel sözlük, dikte geçmişi penceresi, istatistik.
- İmzalı .app paketleme / py2app, launchd ile otomatik başlatma (v1'de sabit launcher script yeter; v2 adayı).
- Windows/Linux desteği.

## Notlar

Sorulamadan varsayılanlar (sonradan teyit edilebilir):

- Pre-roll süresi 0.5 sn, Cmd-V sonrası pano geri yükleme beklemesi ~300 ms — pratik değerler, gerekirse ayarlanır.
- Kayıt üst sınırı ~2 dk (bellek koruması); aşarsa kayıt otomatik biter ve eldeki ses işlenir.
- Qwen3 4B kurulumda Ollama ile birlikte indirilir (~2.5 GB); 16 GB RAM'de whisper turbo (~1.6 GB) ile yan yana çalışabilir.
- Mikrofon: sistem varsayılan giriş aygıtı kullanılır, aygıt seçimi UI'ı yok.
- Kısayol sağ Option'a sabit; ayarlanabilir kısayol v2.
- LLM temizliği menü barından aç/kapa yapılabilir; varsayılan: açık (Ollama erişilebilirse).

## Ek — Paketleme / indirilebilir uygulama (2026-07-03)

**Problem:** v1 sabit `Wispherklon.command` launcher script ile çalışıyor — repo klonlanıp elle kuruluyor. Kullanıcı artık GitHub release'inden indirilip çift tıkla açılan, dağıtılabilir bir uygulama istiyor. Ama Apple Developer hesabı ($99/yıl) yok → imzalı+notarize edilmiş .app yolu kapalı. Hedef: imzasız/ad-hoc bir .app ile kullanıcıyı *mümkün olan en az uğraşa* sokmak.

**Çözüm:**
- **py2app ile ad-hoc imzalı .app** (Apple sertifikası yok; ad-hoc `codesign -s -`). GitHub release'ine `.zip`/`.dmg` olarak konur.
- **Gatekeeper aşımı — tek komutluk kurulum scripti:** indiren kullanıcı README'deki tek satırlık komutu (`xattr -dr com.apple.quarantine Wispherklon.app` + izin yönlendirme) Terminal'e yapıştırır; sonrası çift tık. İmza gerektirmeyen, dürüst çözüm.
- **API/gizli anahtar sızdırma YOK:** kullanıcının (Üveys) API anahtarları .app'e gömülmez. İndiren her PC LLM'i *kendi makinesine* çeker — tam yerel felsefesiyle uyumlu.
- **İlk açılışta otomatik kurulum:** Whisper modeli (large-v3-turbo, ~1.6 GB) yoksa HF'den indirilir (VidScribe kopyası varsa paylaşılır — mevcut mantık). Ollama kuruluysa model çekilir, değilse kullanıcı yönlendirilir. LLM zaten opsiyonel/varsayılan kapalı.
- **Model .app dışında:** bundle'a gömülmez → .app küçük kalır (~50 MB), ilk açılışta iner.
- **İzin stratejisi korunur:** TCC izni sabit binary'ye bağlanır (bkz. Kararlar [2026-07-03] izin stratejisi). .app bundle'ının binary yolu sabit olduğu için izinler .app'e bir kez verilir, kalıcı olur — v1'deki launcher tuzağının .app karşılığı. Ad-hoc imza her build'de değişebileceğinden, izinlerin yeniden istenmesi bilinen risk (test edilecek).

**Kabul kriterleri (paketleme):**
- [ ] GitHub release'inden indirilen `.zip`/`.dmg`, tek komutluk karantina-kaldırma sonrası çift tıkla açılır.
- [ ] .app menü barında çalışır, v1'in tüm dikte akışı (bas-konuş → enjeksiyon) korunur.
- [ ] İlk açılışta Whisper modeli yoksa otomatik iner; Ollama yoksa kullanıcı net yönlendirilir (uygulama LLM'siz de çalışır).
- [ ] Kullanıcının API anahtarı / gizli bilgisi .app içinde YOK.
- [ ] Mikrofon/Giriş İzleme/Erişilebilirlik izinleri .app'e verilebilir ve normal kullanımda kalıcı olur.
- [ ] README'de indir→kur→izin adımları, en az uğraşla, açıkça yazılı.

**Kapsam dışı (paketleme):**
- İmzalı + notarize .app (Apple Developer hesabı gerektirir — şu an yok).
- Otomatik güncelleme (Sparkle vb.).
- launchd ile açılışta otomatik başlatma (v3 adayı).
- App Store dağıtımı.

## Değişiklik Notları

> Append-only. Yön/kapsam değiştiğinde: `[YYYY-AA-GG] ne değişti — bkz. Kararlar [tarih]`. Gövde sessizce yeniden yazılmaz.

- [2026-07-03] Kapsam genişletildi: "imzalı .app paketleme / py2app" (v1'de Kapsam Dışı → v2 adayıydı) bilinçli olarak sonraki oturumun hedefi yapıldı — indirilebilir/dağıtılabilir uygulama. Kullanıcı isteği. Mini-PRD döngüsü sonraki oturumda işlenecek; ayrıntılı kabul kriterleri o zaman `## Ek — paketleme` olarak yazılacak.
- [2026-07-03] Mini-PRD işlendi → `## Ek — Paketleme` eklendi. Paketleme yöntemi imzalı .app DEĞİL, **ad-hoc imzasız .app + tek komutluk karantina-kaldırma** olarak netleşti (Apple Developer hesabı yok). Kullanıcı API anahtarı gömülmeyecek; LLM indiren PC'de yerel çekilir — bkz. Kararlar [2026-07-03] paketleme.

---
[[Context]] — ana hub
