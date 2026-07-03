# Wispherklon

Wispr Flow'un tamamen yerel/offline Türkçe dikte klonu. macOS menü barında yaşar.
**Sağ Option (⌥)** tuşuna basılı tut → konuş → bırak. whisper.cpp sesi Türkçe'ye
çevirir, dolgular temizlenir, metin aktif uygulamanın imlecine yazılır. **Ses makineden çıkmaz.**

## Kurulum

```bash
python3.14 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Whisper modeli (`ggml-large-v3-turbo.bin`, ~1.5 GB) ilk açılışta yoksa otomatik
indirilir; VidScribe'ınki varsa paylaşılır
(`~/Library/Application Support/VidScribe/models/`).

### Opsiyonel — LLM temizliği (Ollama)

Noktalama/akıcılık için Ollama + qwen3:4b. Yoksa uygulama sorunsuz regex-only çalışır.

```bash
brew install ollama
ollama pull qwen3:4b
```

## Çalıştırma

```bash
./Wispherklon.command
```

Menü barında 🎙️ ikonu çıkar. **Sağ Option** basılı tut-konuş-bırak.

## macOS İzinleri (ilk çalıştırmada bir kez)

İzinler, izni çağıran **binary**'ye bağlanır. Hep `Wispherklon.command` üzerinden
başlat ki izin bir kez verilsin ve kalıcı olsun. **Sistem Ayarları → Gizlilik ve Güvenlik:**

| İzin | Ne için | Nerede |
|---|---|---|
| **Mikrofon** | Sesi yakalamak | Gizlilik → Mikrofon |
| **Giriş İzleme** (Input Monitoring) | Sağ ⌥ tuşunu dinlemek | Gizlilik → Giriş İzleme |
| **Erişilebilirlik** (Accessibility) | Cmd-V ile metni yazmak | Gizlilik → Erişilebilirlik |

Listede çıkan öğe genelde **Terminal** (veya launcher'ı başlatan uygulama) olur —
onu işaretle. İzin verdikten sonra uygulamayı yeniden başlat.

## Menü

- **🎙️ boşta · 🔴 kayıt · ✍️ işleniyor · ⏳ yükleniyor**
- **LLM temizliği (Ollama)** — aç/kapa
- **Çıkış**

## Nasıl çalışır

`sounddevice` (16 kHz mono, ~0.5 sn pre-roll) → `pywhispercpp` large-v3-turbo (dil `tr`,
açılışta bir kez yüklenir, sıcak tutulur) → regex dolgu temizliği (+opsiyonel Ollama) →
`NSPasteboard` + Quartz Cmd-V enjeksiyon (eski pano geri yüklenir).

Detaylı hedef/karar/durum: [`brain/`](brain/).
