# SCRIBEME — Context

**Durum:** ✅ v1 TAMAM · ✅ v2 YAYINDA · 🔧 v3 (ScribeMe adı + DMG) — kod ve DMG hazır, canlı dikte testi bekliyor  
**Son güncelleme:** 2026-08-26 · **Son lint:** 2026-07-03 *(gecikti — bir sonraki oturumda atılmalı)*  
**Repo:** https://github.com/uveyscolak/ScribeMe · **Stack:** Python 3.14 (pywhispercpp, sounddevice, pynput, rumps, pyobjc) + opsiyonel Ollama · **Deploy:** lokal macOS menü barı uygulaması (Mac mini, M4, 16 GB)

## Şu An Nerede

- **🔧 v3 — Wispherklon artık ScribeMe (2026-08-26):** ad değişikliği kodun tamamında uygulandı (paket `scribeme/`, bundle kimliği `com.uveyscolak.scribeme`, launcher `ScribeMe.command`, README, `kur.command`), sürüm v3.0.0. Dağıtım ZIP'ten DMG'ye geçti. Gerekçeler: Kararlar [2026-08-26] (iki karar: yeniden adlandırma + dağıtım formatı), kapsam: [[PRD]] `## Ek — ScribeMe yeniden adlandırma`.
  - **Doğrulanan:** `build.sh` tek komutla `dist/ScribeMe.app` (75 MB) + `dist/ScribeMe-3.0.0.dmg` (26 MB) üretiyor; DMG içinde app + `kur.command` + Applications kısayolu, ad-hoc imza geçerli. DMG'den `/Applications`'a kurulup başlatıldı, süreç ayakta.
  - **Doğrulanan — veri göçü:** `config.migrate_legacy_data_dir()` çalıştı, `~/Library/Application Support/Wispherklon` → `ScribeMe` taşındı, 1.6 GB model yeniden inmedi.
  - **Bekleyen:** izinler yeni kimliğe verilmedi (log: *"This process is not trusted"* — beklenen). İzinler verilip canlı dikte denenmeden release yayınlanmayacak.
- **✅ v1 BİTTİ (2026-07-03):** Tüm PRD kabul kriterleri test edilip geçti. Gün içinde üç büyük iş çözüldü:
  1. **Ana dikte bug'ı:** `_poll_mic`'in `sd._terminate()/_initialize()`'ı açık stream'i öldürüyordu (repro ile kanıtlandı) → stream açıkken PortAudio'ya dokunulmaz, sağlık kontrolü `stream_alive()`. Ek: peak normalizasyon + sessizlik kapısı. Detay [[Bug-Defteri]].
  2. **SIGTRAP crash:** worker thread'den UI güncellemesi menü açıkken çökertiyordu → tüm UI dokunuşları `AppHelper.callAfter` ile ana thread'e (bkz. Kararlar).
  3. **LLM temizliği #2:** qwen2.5:3b elendi (prompt sızıntısı/Çince/kişi kayması); model `qwen3:4b-instruct` + few-shot prompt'a geçti ama 4B sınıfı hâlâ güvenilmez ("verdim→verildi") → **varsayılan KAPALI** kaldı, menüden bilinçli açılır (bkz. Kararlar).
- **✅ v2 (2026-07-03):** py2app paketleme, ad-hoc imza, `kur.command`, GitHub release v2.0.0. Paketli .app'ten uçtan uca canlı dikte geçti (log kanıtlı). Kritik bug: .app'te ASCII locale → Türkçe print worker'ı öldürüyordu (bkz. Kararlar [2026-07-03] UTF-8).
- Teşhis logu `/tmp/scribeme.log` (kayıt RMS/süre, ham transkript, temiz metin, enjeksiyon).
- Elenmiş modeller diskten silindi (2026-07-03): `qwen2.5:3b-instruct` + `qwen3:4b` → ~4.1 GB boşaldı. Kalan tek model: `qwen3:4b-instruct` (kullanımdaki). Elenme gerekçeleri Kararlar'da, tekrar denemeye gerek yok.

## Sıradaki Adım

1. **Canlı dikte testi (kullanıcı):** `/Applications/ScribeMe.app` için Mikrofon + Giriş İzleme + Erişilebilirlik izinlerini ver, uygulamayı yeniden başlat, sağ ⌥ ile dikte dene. Bu geçmeden release yayınlanmaz.
2. **Yayın:** `gh repo rename ScribeMe`, git remote güncelle, v3.0.0 release'i aç, `ScribeMe-3.0.0.dmg` yükle.
3. **Yerel klasör taşıma (en son):** `Documents/Claude/Wispherklon` → `ScribeMe`, `.claude/settings.json`'daki mutlak yol düzeltilir, Claude'un proje hafıza dizini yeni yola kopyalanır. Sonrasında Claude yeni klasörde açılmalı.
4. **🔍 Kod denetimi (2026-07-23) — bulgular [[Denetim-2026-07-23]]'te.** Düzeltmeler kullanıcıyla TEK TEK karar verilerek yapılacak, toplu düzeltme YOK. En kritik ikisi: (a) Accessibility izni yoksa dikte metni sessizce kayboluyor (injector güvenlik ağı gerekiyor), (b) dikte metinleri herkese açık `/tmp/scribeme.log`'a yazılıyor (gizlilik). Tam liste ve "Önce şunları yap" sıralaması raporda.
5. **Lint gecikti** — son lint 2026-07-03, iki haftayı fazlasıyla aştı.
6. **Günlük kullanım gözlemi** — stabilite, farklı uygulamalarda enjeksiyon, izin kalıcılığı (özellikle ad-hoc: rebuild sonrası izinler sıfırlanıyor, canlıda 2 kez yaşandı).
7. **LLM kalitesi (opsiyonel):** 8B+ model dene; 4B sınıfı yetersiz kanıtlandı.

## v3 Bitiş Çizgisi — ScribeMe + DMG

[Detay: [[PRD]] Ek — ScribeMe yeniden adlandırma]

- [x] Kaynakta, bundle kimliğinde ve kullanıcıya görünen her metinde ad ScribeMe *(kasıtlı geçiş notları hariç)*
- [x] `build.sh` tek komutla `.app` + `.dmg` üretir; DMG'de app, kur.command ve Applications kısayolu var, ad-hoc imza geçerli
- [x] Eski veri klasörü otomatik taşınır, model yeniden inmez *(canlı doğrulandı: 1.6 GB dosya yerinde)*
- [x] .app DMG'den /Applications'a kurulup başlar *(canlı doğrulandı)*
- [ ] İzinler yeniden verildikten sonra uçtan uca canlı dikte çalışır
- [ ] GitHub reposu ScribeMe adında, v3.0.0 release'inde DMG indirilebilir

## Bitiş Çizgisi — v1

[PRD Kabul Kriterleri'nin özeti. Detay: [[PRD]]] — **TAMAMI GEÇTİ (2026-07-03)**

- [x] Menü barı uygulaması; model açılışta bir kez yüklenir, ikon durum yansıtır
- [x] Herhangi bir uygulamada bas-konuş → metin imlece yazılır *(canlı + sentetik testler)*
- [x] Türkçe karakterler sorunsuz + pano geri yüklenir *(pano sentinel testiyle doğrulandı)*
- [x] Regex dolgu temizliği çalışır
- [x] Ollama LLM menüden açılıp kapanabilir; kapalıyken regex-only sorunsuz *(LLM kalitesi bilinen sınırlama — [[Bug-Defteri]])*
- [x] 5–10 sn dikte ≤2 sn'de yazılır (LLM kapalı, M4) *(canlıda ~1-2 sn)*
- [x] <0.5 sn basmalarda hiçbir şey yazılmaz *(sentetik kısa basma testi geçti)*
- [x] İnternetsiz uçtan uca çalışır *(Wi-Fi kapatılarak test edildi, geçti)*

## Bitiş Çizgisi — v2 Paketleme

[Detay: [[PRD]] Ek — Paketleme] — **TAMAMI GEÇTİ (2026-07-03)**

- [x] GitHub release yayında: **v2.0.0** — `Wispherklon-Kurulum.zip` (kur.command + .app, 27 MB). v3'te DMG'ye geçildi; v2 release'i tarihsel değer olarak yerinde bırakıldı.
- [x] .app menü barında çalışır, v1 dikte akışı korunur *(canlı dikte log kanıtlı geçti)*
- [x] İlk açılışta Whisper modeli yoksa otomatik iner *(kod hazır; temiz makine testi hâlâ yapılmadı)*; Ollama yoksa menüden yönlendirme + onaylı model indirme var; LLM'siz tam çalışır
- [x] Kullanıcının API anahtarı / gizli bilgisi .app içinde YOK *(grep taraması temiz)*
- [x] Mikrofon/Giriş İzleme/Erişilebilirlik izinleri .app'e verildi, dikte çalıştı
- [x] README indir→kur→izin akışıyla yeniden yazıldı + `Kurulum/kur.command` tek-tık kurulum

## Açık Sorular

- **Temiz makine testi hiç yapılmadı:** başka bir Mac'te DMG indirme + ilk açılışta ~1.5 GB model indirme akışı denenmedi. Bu makinede model zaten vardı.
- İzin kalıcılığı: birkaç gün / yeniden başlatma sonrası teyit edilince Kararlar'a işlenecek. **Ad-hoc gerçeği (yaşandı):** her rebuild imzayı değiştiriyor → izinler sıfırlanıyor; sık release'te kullanıcı her sürümde izinleri yeniden verir. Çözüm adayı: self-signed sabit sertifika (Apple hesabı gerektirmez) — ihtiyaç doğarsa araştırılacak.
- TCC izinleri terminalden VERİLEMEZ (Apple güvenlik duvarı — sadece sıfırlama var, `tccutil reset`); kur.command'ın yapabildiği en fazlası doğru panelleri açmak. Mikrofon izni istisna: plist'teki `NSMicrophoneUsageDescription` sayesinde ilk kayıtta otomatik sorulur.

## Alt Sayfalar

- [[PRD]] — hedef, kapsam, kabul kriterleri, kapsam dışı
- [[Bug-Defteri]] — açık bug: mikrofon sesi gelmiyor + kayıt kısa (teşhis + sonraki adımlar)
- [[Denetim-2026-07-23]] — kod denetim raporu: mantık hataları, riskler, öncelik listesi (düzeltmeler tek tek onayla yapılacak)
