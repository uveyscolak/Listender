# WISPHERKLON — Context

**Durum:** 🟡 kurulum  
**Son güncelleme:** 2026-07-03 · **Son lint:** 2026-07-03  
**Repo:** [repo-url] · **Stack:** Python 3 (pywhispercpp, sounddevice, pynput, rumps, pyobjc) + opsiyonel Ollama/Qwen3-4B · **Deploy:** lokal macOS menü barı uygulaması (M4, 16 GB)

## Şu An Nerede

- Kurulum tamamlandı: PRD yazıldı ve onaylandı, beyin yapısı kuruldu. Henüz kod yok.
- Mimari araştırması yapıldı (Wispr Flow bulut tabanlı çıktı; açık kaynak referans: `savbell/whisper-writer` — %100 Python, aynı zincir). Bulguların karar özeti [[PRD]] ve Kararlar'da.
- Hazır motor referansı: `/Users/minvaltaki/Documents/Claude/Video Indir/app/whisper_engine.py` (pywhispercpp, offline; model indirme + transcribe deseni buradan uyarlanacak — model her çağrıda yükleniyor, bizde açılışta bir kez yüklenecek). Model dosyası zaten diskte: `~/Library/Application Support/VidScribe/models/ggml-large-v3-turbo.bin`.
- Ollama makinede henüz kurulu DEĞİL — LLM temizlik katmanı için kurulacak (qwen3:4b).

## Sıradaki Adım

1. Python ortamı + bağımlılıklar (`pywhispercpp, sounddevice, pynput, rumps, pyobjc`) ve proje iskeleti.
2. İlk dikey dilim: sağ Option bas-konuş → mikrofon yakala → whisper (TR) → terminale yazdır (enjeksiyon sonraki dilim).
3. macOS izinlerini sabit launcher üzerinden ver (Mikrofon + Input Monitoring + Accessibility).

## Bitiş Çizgisi

[PRD Kabul Kriterleri'nin özeti — tamamlandıkça işaretle. Detay: [[PRD]]]

- [ ] Menü barı uygulaması; model açılışta bir kez yüklenir, ikon durum yansıtır
- [ ] Herhangi bir uygulamada bas-konuş → metin imlece yazılır
- [ ] Türkçe karakterler sorunsuz + pano geri yüklenir
- [ ] Regex dolgu temizliği çalışır
- [ ] Ollama LLM temizliği açılıp kapanabilir; Ollama yokken regex-only sorunsuz
- [ ] 5–10 sn dikte ≤2 sn'de yazılır (LLM kapalı, M4)
- [ ] <0.5 sn basmalarda hiçbir şey yazılmaz
- [ ] İnternetsiz uçtan uca çalışır

## Açık Sorular

- İzin stratejisinin pratikte nasıl davranacağı (venv python'una izin verme vs sabit launcher) ilk dikey dilimde test edilecek — sonuç Kararlar'a işlenecek.

## Alt Sayfalar

- [[PRD]] — hedef, kapsam, kabul kriterleri, kapsam dışı
