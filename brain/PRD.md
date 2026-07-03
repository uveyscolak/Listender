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

## Değişiklik Notları

> Append-only. Yön/kapsam değiştiğinde: `[YYYY-AA-GG] ne değişti — bkz. Kararlar [tarih]`. Gövde sessizce yeniden yazılmaz.

---
[[Context]] — ana hub
