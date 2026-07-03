# WISPHERKLON — Context

**Durum:** 🟠 canlı test yapıldı — parçalar çalışıyor, 1 açık bug (mikrofon sesi gelmiyor + kayıt kısa)  
**Son güncelleme:** 2026-07-03 · **Son lint:** 2026-07-03  
**Repo:** https://github.com/uveyscolak/Wispherklon · **Stack:** Python 3.14 (pywhispercpp, sounddevice, pynput, rumps, pyobjc) + opsiyonel Ollama · **Deploy:** lokal macOS menü barı uygulaması (Mac mini, M4, 16 GB)

## Şu An Nerede

- **Canlı test yapıldı (2026-07-03, "Wireless Microphone RX" bağlı).** Çoğu parça çalışıyor, tek açık bug var → detay [[Bug-Defteri]].
- **✅ Enjeksiyon çalışıyor:** izole test edildi, metin TextEdit'e yazıldı (pano+Cmd-V). Erişilebilirlik izni verildi, "not trusted" uyarısı kayboldu.
- **✅ Whisper motoru + regex temizliği + mikrofon hot-plug** çalışıyor.
- **🔴 AÇIK BUG:** sağ ⌥ bas-konuş → imlece yazı gelmiyor. Log teşhisi: kayıt sadece **0.5 sn** ve **RMS=0.0003 (sessiz)** → mikrofondan uygulamaya ses ulaşmıyor, whisper "Altyazı M.K." halüsinasyonu üretiyor, filtre eleyince boş kalıyor. Kod zinciri doğru; sorun ses girişinde + kayıt süresinde. Tam analiz + sonraki adımlar [[Bug-Defteri]]. Bug logu: `brain/son-bug-logu.txt`.
- **Ollama + modeller kuruldu:** qwen3:4b (thinking kapatılamadı, elendi) ve qwen2.5:3b-instruct (hızlı ama anlam bozuyor). LLM temizliği şimdilik **varsayılan KAPALI**, regex-only güvenilir (bkz. Kararlar [2026-07-03]).
- **Eklendi:** `_process`'e teşhis log'u (kayıt RMS/süre, ham transkript, temiz metin, enjeksiyon) — `/tmp/wispherklon.log`'a düşüyor.

## Sıradaki Adım

1. **BUG ÇÖZ (öncelik):** [[Bug-Defteri]]'ndeki iki katman —
   (a) uygulamada hangi giriş aygıtı kullanılıyor logla, gerekirse `InputStream(device=...)` explicit ver;
   (b) kayıt 0.5 sn kalıyor → `_begin`/`_end` press-release sırasını logla (pynput alt_r davranışı);
   (c) mik seviyesi: Sistem Ayarları → Ses → Giriş gain + kablosuz verici açık mı.
2. Bug çözülünce uçtan uca tekrar test → Bitiş Çizgisi'ni işaretle.
3. **LLM kalitesi (opsiyonel):** qwen2.5:3b anlam bozuyor; few-shot prompt / daha uyumlu model.

## Bitiş Çizgisi

[PRD Kabul Kriterleri'nin özeti. Detay: [[PRD]]]

- [x] Menü barı uygulaması; model açılışta bir kez yüklenir, ikon durum yansıtır *(kodlandı+smoke test)*
- [ ] Herhangi bir uygulamada bas-konuş → metin imlece yazılır *(mikrofonla test bekliyor)*
- [ ] Türkçe karakterler sorunsuz + pano geri yüklenir *(mikrofonla test bekliyor)*
- [x] Regex dolgu temizliği çalışır *(test edildi)*
- [~] Ollama LLM açılıp kapanabilir; Ollama yokken regex-only sorunsuz *(altyapı hazır, LLM kalitesi iyileştirme bekliyor)*
- [x] 5–10 sn dikte ≤2 sn'de yazılır (LLM kapalı, M4) *(transkript ~1 sn ölçüldü)*
- [ ] <0.5 sn basmalarda hiçbir şey yazılmaz *(kod hazır: MIN_RECORD_SEC filtresi; canlı test bekliyor)*
- [ ] İnternetsiz uçtan uca çalışır *(model diskte; canlı test bekliyor)*

## Açık Sorular

- İzin stratejisinin pratikte davranışı (sabit launcher → Terminal'e verilen izin kalıcı mı) ilk canlı testte doğrulanacak → Kararlar'a.
- LLM anlam-koruma: qwen2.5:3b yetersiz. Prompt mı, model mi? (few-shot örnekli prompt denenebilir.)

## Alt Sayfalar

- [[PRD]] — hedef, kapsam, kabul kriterleri, kapsam dışı
- [[Bug-Defteri]] — açık bug: mikrofon sesi gelmiyor + kayıt kısa (teşhis + sonraki adımlar)
