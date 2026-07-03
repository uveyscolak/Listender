# WISPHERKLON — Bug Defteri
**Açıldı:** 2026-07-03 · **Bağlı:** [[Context]]

Bilinen sorunlar, geçici çözümler, kök nedenler.

---

## 🔴 AÇIK — Mikrofondan uygulamaya ses gelmiyor + kayıt çok kısa

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
