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
