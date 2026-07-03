# WISPHERKLON — Context

**Durum:** ✅ v1 TAMAM — PRD'nin TÜM kabul kriterleri test edildi ve geçti (2026-07-03)  
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

1. **Günlük kullanım gözlemi** — stabilite, farklı uygulamalarda enjeksiyon davranışı, izin kalıcılığı (birkaç yeniden başlatma sonrası).
2. **LLM kalitesi (opsiyonel, v2):** 8B+ model dene; 4B sınıfı yetersiz kanıtlandı.
3. v2 adayları PRD Kapsam Dışı'nda duruyor (toggle mod, streaming, .app paketleme, ayarlanabilir kısayol).

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

## Açık Sorular

- İzin kalıcılığı: bugün launcher üzerinden verilen izinler oturum boyu sorunsuzdu; birkaç gün / yeniden başlatma sonrası teyit edilince Kararlar'a işlenecek.

## Alt Sayfalar

- [[PRD]] — hedef, kapsam, kabul kriterleri, kapsam dışı
- [[Bug-Defteri]] — açık bug: mikrofon sesi gelmiyor + kayıt kısa (teşhis + sonraki adımlar)
