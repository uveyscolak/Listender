# LISTENDER — Context

**Durum:** 🟡 Swift sürümü yazıldı ve makine testlerinden geçti — **canlı dikte henüz denenmedi**
**Son güncelleme:** 2026-09-02
**Repo:** https://github.com/uveyscolak/Listender (private) · **Stack:** Swift 6 + AppKit + WhisperKit (SwiftPM) · **Deploy:** yerel klondan `scripts/install.sh`

## Şu An Nerede

Python sürümü (v2.0.0) tamamen Swift'e taşındı. Droper'ın paket düzeni uygulandı:
`ListenderKit` kütüphanesi bütün mantığı taşıyor, `Sources/Listender/main.swift`
yalnız giriş noktası.

**Karşılıklar:** sounddevice → `AVAudioEngine` (artı 16 kHz'e dönüştürme), pynput →
`CGEventTap` (sağ ⌥), rumps → `NSStatusItem`, pywhispercpp → **WhisperKit**,
pano ve Cmd-V → `NSPasteboard` + `CGEvent`, Ollama → `URLSession`.

**Doğrulananlar:**
- 25 test, 9 suite geçiyor. Temizlik hattının bütün davranışları test altında.
- `listender-temizlik-smoke` ve `listender-ses-testi` tanı komutları çalışıyor.
- Paketlenmiş `.app`'ten tam zincir: model yükleme, transkript, temizlik.
- `codesign --verify --strict --deep` geçiyor.
- **Ölçüm (M2 Pro):** 6 sn ses → 0,8 sn transkript, kusursuz Türkçe.
  Model yükleme ilk açılışta ~135 sn (CoreML derlemesi), sonrasında ~7 sn.

**Yol boyunca çözülen üç tuzak** — hepsi [[Kararlar]] 2026-09-02'de:
whisper.cpp'nin SwiftPM desteğini bırakmış olması, `prewarm`/`load` bayrakları
olmadan her şeyin CPU hızına düşmesi, `promptTokens`'ın transkripti boşaltması.
Ayrıca Türkçe `lowercased()` kusuru yüzünden halüsinasyon filtresinin hiç
çalışmadığı ortaya çıktı — aynı kusur Python sürümünde de vardı.

Python kodu silindi; `1acad4d` ve öncesi commit'lerde duruyor, gerekirse geri gelir.

## Sıradaki Adım

1. **Canlı dikte testi — en kritik eksik.** Makine testleri mikrofonu, sağ ⌥
   dinleyicisini ve enjeksiyonu kapsamıyor; üçü de izin gerektiriyor ve insan
   eliyle denenmeli. `open /Applications/Listender.app`, izinleri ver, herhangi
   bir yerde sağ ⌥ tuşuna basılı tutup konuş.
2. Repo özel. Tomar'ın aksine burada telifli içerik yok (model çalışma anında
   iniyor, kod tamamen kendi kodumuz), istenirse herkese açık yapılıp Droper gibi
   `curl | bash` tek satır kuruluma geçilebilir. Üveys'e sorulacak.
3. Ollama katmanı bu makinede hiç denenmedi (Ollama kurulu değil).
4. Uygulama ikonu yok.

## Bitiş Çizgisi

[[PRD]]'deki kabul kriterleri Python sürümünde geçmişti. Swift sürümünde
makineyle doğrulanabilenler geçti; **mikrofon, tuş ve enjeksiyon maddeleri
canlı testi bekliyor.**

## Alt Sayfalar

- [[PRD]] — hedef, kapsam, kabul kriterleri
- [[Kararlar]] — neden öyle yapıldığı
- [[Bug-Defteri]] — Python dönemindeki bug geçmişi
- [[Denetim-2026-07-23]] — kod denetim raporu; gizlilik ve izin bulguları Swift'te giderildi
