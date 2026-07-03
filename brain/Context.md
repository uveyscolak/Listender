# WISPHERKLON — Context

**Durum:** 🟢 çalışır (ilk sürüm kodlandı, mikrofonla uçtan uca test kaldı)  
**Son güncelleme:** 2026-07-03 · **Son lint:** 2026-07-03  
**Repo:** https://github.com/uveyscolak/Wispherklon · **Stack:** Python 3.14 (pywhispercpp, sounddevice, pynput, rumps, pyobjc) + opsiyonel Ollama · **Deploy:** lokal macOS menü barı uygulaması (Mac mini, M4, 16 GB)

## Şu An Nerede

- **Uygulama kodlandı ve çalışıyor.** Tüm modüller yazıldı, importlar temiz, smoke test geçti (model yükleniyor→hazır, çökme yok). Kod: `wispherklon/` (config, transcriber, recorder, cleaner, injector, app) + `run.py` + `Wispherklon.command` launcher + README.
- **Whisper zinciri kanıtlandı:** model diskte (1.5 GB, `~/Library/Application Support/VidScribe/models/ggml-large-v3-turbo.bin`), açılışta 5 sn'de yüklenir+ısınır, transkript ~1 sn (PRD ≤2 sn ✓).
- **Regex temizliği test edildi, doğru çalışıyor** (dolgu at, cümle-başı yumuşak dolgu, halüsinasyon filtresi).
- **Mikrofon hot-plug hazır:** bu makinede şu an mikrofon YOK; uygulama 🚫 gösterip bekliyor, mikrofon takılınca 2 sn içinde otomatik hazır olacak (bkz. Kararlar [2026-07-03]).
- **Ollama + modeller kuruldu:** qwen3:4b (thinking kapatılamadı, elendi) ve qwen2.5:3b-instruct (hızlı ama anlam bozuyor). LLM temizliği şimdilik **varsayılan KAPALI**, regex-only güvenilir (bkz. Kararlar [2026-07-03]).

## Sıradaki Adım

1. **Mikrofonla uçtan uca test** (kullanıcı yapacak): mikrofon bağla → `./Wispherklon.command` → macOS izinleri ver (Mikrofon + Giriş İzleme + Erişilebilirlik, Terminal'e) → herhangi bir uygulamada sağ ⌥ bas-konuş → metin imlece yazılıyor mu?
2. İzin akışını gerçek launcher'da doğrula, sonucu Kararlar'a işle (açık soru).
3. **LLM kalitesi (opsiyonel iyileştirme):** qwen2.5:3b anlam bozuyor; prompt mühendisliği veya daha uyumlu/büyük model ile "anlamı koru" davranışı çözülünce LLM varsayılan açılabilir.

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
