# WISPHERKLON — Context

**Durum:** 🟢 ÇALIŞIYOR — ana bug çözüldü, canlı dikte uçtan uca doğrulandı (2 başarılı test)  
**Son güncelleme:** 2026-07-03 · **Son lint:** 2026-07-03  
**Repo:** https://github.com/uveyscolak/Wispherklon · **Stack:** Python 3.14 (pywhispercpp, sounddevice, pynput, rumps, pyobjc) + opsiyonel Ollama · **Deploy:** lokal macOS menü barı uygulaması (Mac mini, M4, 16 GB)

## Şu An Nerede

- **✅ ANA BUG ÇÖZÜLDÜ (2026-07-03):** "mikrofon sesi gelmiyor + kayıt 0.5 sn" — kök neden `_poll_mic`'in her 2 sn'de `sd._terminate()/_initialize()` çağırıp **açık stream'i öldürmesiydi** (repro ile kanıtlandı). Fix: stream açıkken PortAudio'ya dokunulmaz, sağlık kontrolü `stream_alive()` ile. Ek: peak normalizasyon + sessizlik kapısı. Detay [[Bug-Defteri]], gerekçe Kararlar [2026-07-03]. İkincil etken: kablosuz mikrofonun vericisi kapalıymış.
- **✅ CANLI DOĞRULANDI:** 2 gerçek dikte — 6.5 sn ve 5.1 sn kayıt (RMS ~0.04), kusursuz Türkçe transkript (noktalama dahil), metin imlece enjekte edildi. Zincirin tamamı çalışıyor: kayıt → whisper → regex temizlik → pano+Cmd-V.
- **✅ Enjeksiyon, whisper motoru, regex temizliği, mikrofon hot-plug** çalışıyor.
- **Ollama + modeller kuruldu:** qwen3:4b (thinking kapatılamadı, elendi) ve qwen2.5:3b-instruct (hızlı ama anlam bozuyor). LLM temizliği şimdilik **varsayılan KAPALI**, regex-only güvenilir (bkz. Kararlar [2026-07-03]).
- Teşhis logu `/tmp/wispherklon.log`'a düşüyor (kayıt RMS/süre, ham transkript, temiz metin, enjeksiyon).

## Sıradaki Adım

1. Kalan Bitiş Çizgisi testleri: **kısa basma** (<0.5 sn → hiçbir şey yazılmamalı), **pano geri yükleme** gözle teyit, **internetsiz** uçtan uca.
2. Günlük kullanımda gözlem — stabilite, farklı uygulamalarda enjeksiyon.
3. **LLM kalitesi (opsiyonel):** qwen2.5:3b anlam bozuyor; few-shot prompt / daha uyumlu model.

## Bitiş Çizgisi

[PRD Kabul Kriterleri'nin özeti. Detay: [[PRD]]]

- [x] Menü barı uygulaması; model açılışta bir kez yüklenir, ikon durum yansıtır *(kodlandı+smoke test)*
- [x] Herhangi bir uygulamada bas-konuş → metin imlece yazılır *(canlı doğrulandı, 2 test — 2026-07-03)*
- [~] Türkçe karakterler sorunsuz *(canlı doğrulandı)* + pano geri yüklenir *(gözle teyit bekliyor)*
- [x] Regex dolgu temizliği çalışır *(test edildi)*
- [~] Ollama LLM açılıp kapanabilir; Ollama yokken regex-only sorunsuz *(altyapı hazır, LLM kalitesi iyileştirme bekliyor)*
- [x] 5–10 sn dikte ≤2 sn'de yazılır (LLM kapalı, M4) *(canlıda ~1-2 sn)*
- [ ] <0.5 sn basmalarda hiçbir şey yazılmaz *(kod hazır: MIN_RECORD_SEC filtresi; canlı test bekliyor)*
- [ ] İnternetsiz uçtan uca çalışır *(model diskte; canlı test bekliyor)*

## Açık Sorular

- İzin stratejisinin pratikte davranışı (sabit launcher → Terminal'e verilen izin kalıcı mı) — bugünkü testte izinler sorunsuz çalıştı; birkaç yeniden başlatma sonrası kalıcılık teyit edilince Kararlar'a işlenecek.
- LLM anlam-koruma: qwen2.5:3b yetersiz. Prompt mı, model mi? (few-shot örnekli prompt denenebilir.)

## Alt Sayfalar

- [[PRD]] — hedef, kapsam, kabul kriterleri, kapsam dışı
- [[Bug-Defteri]] — açık bug: mikrofon sesi gelmiyor + kayıt kısa (teşhis + sonraki adımlar)
