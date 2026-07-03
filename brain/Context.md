# WISPHERKLON — Context

**Durum:** ✅ v1 TAMAM · ✅ v2 YAYINDA — GitHub release v2.0.0, .app'ten canlı dikte geçti  
**Son güncelleme:** 2026-07-03 · **Son lint:** 2026-07-03  
**Repo:** https://github.com/uveyscolak/Wispherklon · **Stack:** Python 3.14 (pywhispercpp, sounddevice, pynput, rumps, pyobjc) + opsiyonel Ollama · **Deploy:** lokal macOS menü barı uygulaması (Mac mini, M4, 16 GB)

## Şu An Nerede

- **✅ v1 BİTTİ (2026-07-03):** Tüm PRD kabul kriterleri test edilip geçti. Gün içinde üç büyük iş çözüldü:
  1. **Ana dikte bug'ı:** `_poll_mic`'in `sd._terminate()/_initialize()`'ı açık stream'i öldürüyordu (repro ile kanıtlandı) → stream açıkken PortAudio'ya dokunulmaz, sağlık kontrolü `stream_alive()`. Ek: peak normalizasyon + sessizlik kapısı. Detay [[Bug-Defteri]].
  2. **SIGTRAP crash:** worker thread'den UI güncellemesi menü açıkken çökertiyordu → tüm UI dokunuşları `AppHelper.callAfter` ile ana thread'e (bkz. Kararlar).
  3. **LLM temizliği #2:** qwen2.5:3b elendi (prompt sızıntısı/Çince/kişi kayması); model `qwen3:4b-instruct` + few-shot prompt'a geçti ama 4B sınıfı hâlâ güvenilmez ("verdim→verildi") → **varsayılan KAPALI** kaldı, menüden bilinçli açılır (bkz. Kararlar).
- **Doğrulama:** 5+ canlı dikte (kullanıcı) + 3 gözetimsiz uçtan uca test (sentetik sağ ⌥ + hoparlörden `say`): kısa basma filtresi, pano geri yükleme (sentinel), **internetsiz tam zincir** (Wi-Fi kapalıyken dikte→enjeksiyon çalıştı).
- Teşhis logu `/tmp/wispherklon.log` (kayıt RMS/süre, ham transkript, temiz metin, enjeksiyon).
- Elenmiş modeller diskten silindi (2026-07-03): `qwen2.5:3b-instruct` + `qwen3:4b` → ~4.1 GB boşaldı. Kalan tek model: `qwen3:4b-instruct` (kullanımdaki). Elenme gerekçeleri Kararlar'da, tekrar denemeye gerek yok.

## Sıradaki Adım

1. **✅ v2 paketleme BİTTİ ve YAYINDA (2026-07-03):** py2app + ad-hoc imza + `build.sh` + `Kurulum/kur.command`. Paketli .app'ten uçtan uca canlı dikte GEÇTİ (log kanıtlı). Kritik bug çözüldü: .app'te ASCII locale → Türkçe print worker'ı öldürüyordu (bkz. Kararlar [2026-07-03] UTF-8). Kod commit'lendi (kullanıcı onayıyla, `3187f4e`), **release v2.0.0 yayınlandı**. Kalan pürüz: temiz makinede indirme + ilk-açılış model indirme testi hiç yapılmadı.
2. **Günlük kullanım gözlemi** — stabilite, farklı uygulamalarda enjeksiyon, izin kalıcılığı (özellikle ad-hoc: rebuild sonrası izinler sıfırlanıyor, canlıda 2 kez yaşandı).
3. **LLM kalitesi (opsiyonel):** 8B+ model dene; 4B sınıfı yetersiz kanıtlandı.

## Bitiş Çizgisi

[PRD Kabul Kriterleri'nin özeti. Detay: [[PRD]]] — **TAMAMI GEÇTİ (2026-07-03)**

- [x] Menü barı uygulaması; model açılışta bir kez yüklenir, ikon durum yansıtır
- [x] Herhangi bir uygulamada bas-konuş → metin imlece yazılır *(canlı + sentetik testler)*
- [x] Türkçe karakterler sorunsuz + pano geri yüklenir *(pano sentinel testiyle doğrulandı)*
- [x] Regex dolgu temizliği çalışır
- [x] Ollama LLM menüden açılıp kapanabilir; kapalıyken regex-only sorunsuz *(LLM kalitesi bilinen sınırlama — [[Bug-Defteri]])*
- [x] 5–10 sn dikte ≤2 sn'de yazılır (LLM kapalı, M4) *(canlıda ~1-2 sn)*
- [x] <0.5 sn basmalarda hiçbir şey yazılmaz *(sentetik kısa basma testi geçti)*
- [x] İnternetsiz uçtan uca çalışır *(Wi-Fi kapatılarak test edildi, geçti)*

## v2 Bitiş Çizgisi — Paketleme

[Detay: [[PRD]] Ek — Paketleme]

- [x] GitHub release yayında: **v2.0.0** — `Wispherklon-Kurulum.zip` (kur.command + .app, 27 MB) → https://github.com/uveyscolak/Wispherklon/releases/tag/v2.0.0 *(indiren: zip aç → kur.command sağ tık→Aç → gerisi otomatik; indirme testi başka makinede yapılmadı)*
- [x] .app menü barında çalışır, v1 dikte akışı korunur *(canlı dikte log kanıtlı geçti, 2026-07-03)*
- [x] İlk açılışta Whisper modeli yoksa otomatik iner *(kod hazır; bu makinede VidScribe kopyası kullanıldı — temiz makine testi bekliyor)*; Ollama yoksa menüden yönlendirme + onaylı model indirme var; LLM'siz tam çalışır
- [x] Kullanıcının API anahtarı / gizli bilgisi .app içinde YOK *(grep taraması temiz)*
- [x] Mikrofon/Giriş İzleme/Erişilebilirlik izinleri .app'e verildi, dikte çalıştı *(kalıcılık gözlemi sürüyor; rebuild izinleri sıfırlıyor — bilinen ad-hoc sınırı)*
- [x] README indir→kur→izin akışıyla yeniden yazıldı + `Kurulum/kur.command` tek-tık kurulum

## Açık Sorular

- İzin kalıcılığı: birkaç gün / yeniden başlatma sonrası teyit edilince Kararlar'a işlenecek. **Ad-hoc gerçeği (yaşandı):** her rebuild imzayı değiştiriyor → izinler sıfırlanıyor; sık release'te kullanıcı her sürümde izinleri yeniden verir. Çözüm adayı: self-signed sabit sertifika (Apple hesabı gerektirmez) — ihtiyaç doğarsa araştırılacak.
- TCC izinleri terminalden VERİLEMEZ (Apple güvenlik duvarı — sadece sıfırlama var, `tccutil reset`); kur.command'ın yapabildiği en fazlası doğru panelleri açmak. Mikrofon izni istisna: plist'teki `NSMicrophoneUsageDescription` sayesinde ilk kayıtta otomatik sorulur.
- Temiz makinede ilk-açılış model indirmesi (~1.5 GB) hiç test edilmedi.

## Alt Sayfalar

- [[PRD]] — hedef, kapsam, kabul kriterleri, kapsam dışı
- [[Bug-Defteri]] — açık bug: mikrofon sesi gelmiyor + kayıt kısa (teşhis + sonraki adımlar)
