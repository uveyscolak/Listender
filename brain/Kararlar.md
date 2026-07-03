# WISPHERKLON — Karar Günlüğü

> NEDEN'in tek evi. Append-only. Her karar: tarih + ne + neden (+ varsa "denedik olmadı"). Eskiler silinmez.

## [2026-07-03] Proje kuruldu — PRD yazıldı ✅

**Mod:** hızlı · **Stack:** Python 3 (pywhispercpp, sounddevice, pynput, rumps, pyobjc)  
**Neden:** Mevcut VidScribe Whisper motoru Python'da — uyum ve kod yeniden kullanımı. En olgun açık kaynak klonlar (Handy/Rust, VoiceInk/Swift) native'e geçmiş olsa da, inference zaten whisper.cpp'ye (native) delege edildiği için Python orkestrasyon katmanı olarak yeterli; `savbell/whisper-writer` bunun çalışan kanıtı.

## [2026-07-03] STT: pywhispercpp + large-v3-turbo, dil sabit Türkçe

**Ne:** whisper.cpp (Metal) üzerinden `large-v3-turbo`; `language="tr"` sabit, otomatik dil algılama yok. VidScribe'ın model dosyası paylaşılır, yeniden indirilmez. Model açılışta bir kez yüklenir, bellekte sıcak tutulur.  
**Neden:** Türkçe'de `small` isabetsiz (WER ~%17), turbo large doğruluğunda + medium hızında; M4'te 5-10 sn dikte ~1 sn. Kullanıcı yalnız Türkçe dikte edecek — sabit dil hem hız hem yanlış algılama riskini sıfırlar. VidScribe'daki her-çağrıda-model-yükleme deseni dikte gecikmesine uymaz — elendi. faster-whisper Mac'te GPU kullanamıyor — elendi.

## [2026-07-03] Tetikleme: bas-konuş, sağ Option (⌥)

**Ne:** Sağ Option basılı tut = kayıt, bırak = transkript + yaz. pynput global listener.  
**Neden:** Tuş = kayıt sınırı → VAD gerekmez, en basit ve sağlam akış. Fn/Globe (Wispr varsayılanı) macOS tarafından rezerve — sistem ayarı + Quartz event tap kırılganlığı nedeniyle elendi. Toggle mod v2'ye ertelendi (kapsam dışı).

## [2026-07-03] Metin enjeksiyonu: pano + Cmd-V, geri yükleme ile

**Ne:** NSPasteboard içeriğini kaydet → metni koy → CGEventPost ile Cmd-V → ~300 ms → eski panoyu geri yükle.  
**Neden:** En hızlı ve Türkçe karakterlerde en güvenilir yöntem; Handy/VoiceInk/FreeFlow fiilen bunu kullanıyor. Karakter karakter klavye simülasyonu (pynput type) macOS'ta Türkçe/büyük harf sorunları nedeniyle elendi; AX API (setValue) Electron/web uygulamalarda güvenilmez — elendi.

## [2026-07-03] Temizlik katmanı: regex + opsiyonel Ollama Qwen3 4B

**Ne:** Whisper çıktısına önce deterministik regex dolgu temizliği; Ollama erişilebilirse `qwen3:4b` ile noktalama/akıcılık düzeltmesi ("anlamı değiştirme" promptu). Ollama yoksa/kapalıysa sessizce regex-only.  
**Neden:** Whisper dolguları ("eee/yani/hani") silmez. Wispr Flow'un kalite farkı LLM post-process'ten geliyor — kullanıcı bu kaliteyi istedi, Ollama kurulumunu kabul etti (makinede yoktu). Qwen3 4B: 16 GB RAM'de whisper ile yan yana çalışır, M4'te ~0.5-1 sn ek gecikme. Regex fallback = LLM tek hata noktası olmasın.

## [2026-07-03] İzin stratejisi: sabit launcher

**Ne:** Mikrofon + Input Monitoring + Accessibility izinleri hep aynı sabit binary/launcher üzerinden verilir; py2app paketleme v2'ye bırakıldı.  
**Neden:** macOS TCC izni koda değil çağıran binary'ye bağlar — venv/python değişince izinler sessizce bozulur (bilinen tuzak). Sabit launcher bunu ucuza çözer; imzalı .app daha temiz ama v1 için gereksiz yük.

## [2026-07-03] Mikrofon hot-plug: yoksa çalışma, takılınca otomatik gel

**Ne:** Açılışta mikrofon yoksa uygulama çökmz — 🚫 ikonu + "bağlanınca hazır olur" durumu gösterir, bas-konuş devre dışı kalır. `rumps.Timer` her 2 sn `sd._terminate()/_initialize()` ile aygıt cache'ini tazeleyip yoklar; mikrofon takılınca stream'i açıp otomatik hazır olur, çekilince tekrar bekleme durumuna döner.
**Neden:** Bu makine (Mac mini) dahili mikrofonsuz; giriş aygıtı sonradan (USB/kamera) bağlanıyor. Kullanıcı "mikrofon bağlı değilse program çalışmasın, bağlanınca otomatik gelen kanalla çalışsın" dedi. sounddevice aygıtları ilk sorguda cache'lediği için çalışırken takılan mikrofon yeniden başlatmadan görünmez → cache tazeleme şart.

## [2026-07-03] Hot-plug yoklaması: stream açıkken PortAudio'ya dokunulmaz

**Ne:** `_poll_mic` iki moda ayrıldı — mikrofon yokken `refresh_devices()` (cache tazele) + ara; mikrofon varken sadece callback-akışı sağlık kontrolü (`stream_alive()`). Ek olarak transkript öncesi peak normalizasyon + RMS sessizlik kapısı eklendi.
**Neden — denedik olmadı (her poll'da refresh):** `sd._terminate()/_initialize()` aktif InputStream'i sessizce öldürüyor (repro: refresh öncesi 66 callback/2sn, sonrası 0). Uygulama açıldıktan 2 sn sonra mikrofon fiilen kopuyordu — canlı testteki "kayıt 0.5 sn + RMS≈0" bug'ının kök nedeni. Callback zaman damgası hem stream ölümünü hem fiziken çekilen mikrofonu tek mekanizmayla yakalar. Normalizasyon: kablosuz mikrofon kısık gelebiliyor (konuşma RMS ~0.009); sessizlik kapısı: verici kapalıyken normalize edilmiş gürültü whisper'da halüsinasyon üretir.

## [2026-07-03] LLM temizlik modeli: qwen3:4b → qwen2.5:3b-instruct, varsayılan KAPALI

**Ne:** LLM post-process modeli qwen3:4b'den qwen2.5:3b-instruct'a geçti; chat endpoint (`/api/chat`) + `keep_alive` kullanılıyor. LLM varsayılan olarak KAPALI başlıyor, menüden manuel açılır.
**Neden — denedik olmadı (qwen3:4b):** thinking modu kapatılamadı — `think:false` (hem generate hem chat), `/no_think` sistem promptu, `num_predict` sınırı hepsi denendi; model her koşulda İngilizce uzun reasoning yapıyor ("Okay, let's tackle this...") ve çağrı 60-130 sn sürüyor. `<think>` etiketi bile gelmediği için strip edilemiyor. Dikte için kabul edilemez → elendi.
**qwen2.5:3b-instruct:** reasoning yok, ısınınca ~0.6 sn (hedefe uygun). ANCAK anlamı bozabiliyor: "bugün"→"günümüz", "müşteriyle"→"müşterimize", "onayladı"→"onayladık". Prompt sıkılaştırması (zaman/kişi koru) yetmedi. Bu yüzden LLM şimdilik KAPALI; regex-only güvenilir varsayılan. Prompt mühendisliği veya daha büyük/uyumlu bir model sonraki oturuma bırakıldı. Regex katmanı test edildi, doğru çalışıyor.
