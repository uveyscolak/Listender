# WISPHERKLON — Bug Defteri
**Açıldı:** 2026-07-03 · **Bağlı:** [[Context]]

Bilinen sorunlar, geçici çözümler, kök nedenler.

---

## ✅ ÇÖZÜLDÜ (2026-07-03) — "Python kendi kendine kapandı" (SIGTRAP crash)

**Belirti:** Kullanıcı LLM'i menüden açıp dikte test ederken uygulama "Python quit unexpectedly" ile kapandı.

**Kök neden (crash raporundan):** Worker thread (`Thread _process`) `NSMenuItem.setTitle` çağırmış — macOS'ta AppKit UI'ına yalnızca ana thread dokunabilir; menü açıkken arka plan thread'inden durum yazısı güncellenince AppKit `EXC_BREAKPOINT/SIGTRAP` ile süreci öldürüyor. Koddaki "kısa metin ataması yeterince güvenli" varsayımı yanlıştı — çoğu zaman şans eseri çalışıyor, menü etkileşimi sırasında çöküyor.

**Fix:** Tüm UI güncellemeleri (`_set_status`, menü barı ikonu → `_set_title`) `AppHelper.callAfter` ile ana thread'e taşındı. Worker, pynput dinleyicisi, timer — hepsi aynı köprüden geçer.

**Doğrulama:** Menü açıkken + LLM açıkken canlı dikte → çökme yok; ardından 3 gözetimsiz uçtan uca test sorunsuz.

---

## ⚠️ BİLİNEN SINIRLAMA — LLM temizliği anlam bozabiliyor (varsayılan KAPALI)

4B sınıfı yerel modeller dikte sadakati için yeterince güvenilir değil (detay: Kararlar [2026-07-03] LLM #2). Denenen: qwen3:4b (thinking kapanmıyor), qwen2.5:3b-instruct (prompt sızıntısı + Çince karakter + kişi kayması), qwen3:4b-instruct + few-shot (en iyisi; marka korur ama hâlâ "verdim→verildi" tarzı kayma yapabiliyor). Regex-only güvenilir varsayılan; LLM menüden bilinçli açılır. Gelecek adaylar: daha büyük model (8B+) veya bulut-dışı başka çözüm.

---

## ✅ ÇÖZÜLDÜ (2026-07-03) — Mikrofondan uygulamaya ses gelmiyor + kayıt çok kısa

**Kök neden (kanıtlı):** `_poll_mic` her 2 sn'de `refresh_devices()` → `sd._terminate()/_initialize()` çağırıyordu — **stream açıkken bile**. PortAudio aktif stream'in altından çekilince stream sessizce ölüyor: callback bir daha hiç gelmiyor. İzole repro testiyle kanıtlandı (refresh öncesi 2 sn'de 66 callback, sonrası 0).

Logdaki 7680 örnek = tam olarak pre-roll tamponu (16 blok × 480) — kayıt sırasında sıfır yeni blok gelmişti. Tek kök neden iki belirtiyi de açıklıyor; pynput/tuş zinciri suçsuzdu. İkincil etken: canlı testte kablosuz mikrofonun **vericisi kapalıymış** (RMS≈0'ın sebebi).

**Fix (kod):**
1. `_poll_mic` iki moda ayrıldı: mikrofon YOKKEN cache tazele+ara; mikrofon VARKEN PortAudio'ya dokunma, sadece sağlık kontrolü (`Recorder.stream_alive()` — son 1.5 sn'de callback geldi mi). Callback durursa (mik çekildi) stream kapatılıp arama moduna dönülür.
2. `Recorder`'a `_last_block_at` + `stream_alive()` eklendi; `start_stream` hangi aygıta bağlandığını logluyor.
3. **Peak normalizasyon** (`transcriber.transcribe`): kısık mikrofon sesi 0.95 tepeye ölçeklenir (konuşma RMS ~0.009 ölçülmüştü).
4. **Sessizlik kapısı** (`_process`): RMS < `SILENCE_RMS` (0.0002) ise whisper'a hiç gitmeden "Ses yok — mikrofon/verici açık mı?" denir (halüsinasyon önlemi).

**Doğrulama:** izole uçtan uca test (hoparlörden `say` ile cümle → mikrofon → whisper: birebir doğru transkript) + canlı kullanıcı testi: 6.5 sn dikte → kusursuz Türkçe transkript → 83 karakter imlece enjekte edildi.

---

## Arşiv — orijinal teşhis (2026-07-03, çözüm öncesi)

**Belirti:** Sağ ⌥ bas-konuş yapılınca menüde "ses yazıya çevriliyor" görünüyor ama imlece hiçbir şey yazılmıyor.

**Teşhis (canlı test logu, 2026-07-03 — `brain/son-bug-logu.txt`):**
```
[dikte] kayıt 0.5sn, 7680 örnek, RMS=0.0003
[dikte] ham transkript: 'Altyazı M.K.'
[dikte] temiz metin: ''
```
Zincir aslında DOĞRU çalışıyor: whisper sessizlikte "Altyazı M.K." halüsinasyonu üretti, halüsinasyon filtresi onu doğru eleyip boş bıraktı → yazacak metin kalmadı → pano dolmadı ("Itsycal" kaldı).

**İki katmanlı kök neden (kod değil, ses girişi):**
1. **RMS=0.0003 ≈ tam sessizlik** — mikrofondan uygulamaya ses ULAŞMIYOR. Oysa aynı mikrofonla izole `Recorder` testinde ses gelmişti (RMS 0.009). Fark: o testte varsayılan aygıt index 2 = "Wireless Microphone RX". Uygulama InputStream'i `device` belirtmeden açıyor → sistem varsayılanını kullanmalı ama seviye sıfır. Kablosuz mik verici (TX) kapalı/pilsiz/uzak olabilir VEYA uygulama süreci farklı/yanlış giriş aygıtına bağlanıyor.
2. **Kayıt sadece 0.5 sn** — kullanıcı tuşu daha uzun tuttuğu halde kayıt 0.5 sn (= sadece pre-roll tamponu kadar). Sağ ⌥ release olayı erken mi geliyor, yoksa `_begin` çağrılmadan `_end` mi işliyor? pynput'ta alt_r press/release davranışı incelenecek.

**KANITLANAN (çalışıyor):**
- ✅ Enjeksiyon (pano+Cmd-V): izole test edildi, "WISPHERKLON-ENJEKSIYON-TESTI-123" TextEdit'e yazıldı.
- ✅ Erişilebilirlik izni: "not trusted" uyarısı kayboldu.
- ✅ Whisper motoru: model yükleniyor, transkript üretiyor.
- ✅ Mikrofon donanımı: izole testte ses geldi (RMS 0.009).

**Sonraki oturumda ilk işler:**
1. Uygulama içinde hangi giriş aygıtının kullanıldığını logla (`sd.query_devices(kind='input')`, stream device index). Gerekirse InputStream'e explicit `device=` ver.
2. Kayıt süresi bug'ı: `_begin`/`_end` çağrı sırasını logla — press gerçekten tutuluyor mu, release ne zaman geliyor.
3. Mik seviyesi: Sistem Ayarları → Ses → Giriş'te "Wireless Microphone RX" seviyesi/gain kontrol; verici açık mı.

---
[[Context]] — ana hub
