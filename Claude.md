# WISPHERKLON — Claude El Kitabı

Wispr Flow'un tamamen yerel/offline klonu: macOS menü barında yaşayan Türkçe sesli dikte asistanı. Sağ Option'a basılı tutup konuş — whisper.cpp sesi yazıya döker, dolgular temizlenir, metin aktif uygulamanın imlecine yazılır. Ses makineden çıkmaz.

**Beyin:** `./brain/` · **Repo:** https://github.com/uveyscolak/Wispherklon · **Stack:** Python 3 (pywhispercpp, sounddevice, pynput, rumps, pyobjc) + opsiyonel Ollama/Qwen3-4B · **Deploy:** lokal macOS menü barı uygulaması (M4, 16 GB)

---

> Bu el kitabı Andrej Karpathy'nin LLM Wiki yaklaşımının proje yönetimine uyarlamasıdır. Ana fikir: bilgi her oturumda sıfırdan türetilmez — **beyin birikir.** İki katman çalışır: **Kod** (bu git reposu — versiyonlu üretim artefaktları) ve **Beyin** (`./brain/` — hedef, kararlar, durum, öğrenilenler; Claude yazar, kullanıcı konuşur). Kullanıcının işi: kaynak getirmek, soru sormak, yön vermek. Claude'un işi: okumak, yazmak, bağlamak, hatırlamak — izin sormadan.

## Her oturum başında — tartışmaya kapalı

`brain/Context.md` okunmadan tek satır üretme. (SessionStart hook bunu oturum başı otomatik yükler; yüklenmemişse sen oku.) "Nerede kaldık?" sorusunun cevabı her zaman buradan gelir — tahmin etme, hatırladığını varsayma. İşle ilgili `## Alt Sayfalar` linki varsa onu da aç.

## Beynin üç direği — ne nereye yazılır

- **`PRD.md` = HEDEF** (kurulumda yazıldı, donmuş spec). Problem, kapsam, kabul kriterleri, kapsam dışı burada yaşar. Günlük iş buradan değil Context'ten yürür; PRD'ye "ne yapıyorduk, bitti mi, bu kapsamda mı" sorularında dönülür.
- **`Kararlar.md` = NEDEN** (append-only). Bir seçim yapıldığında: tarih + ne + neden + varsa "denedik olmadı". Gerekçe **yalnızca burada** yaşar. Eskiyi silme — geçersiz kalsa bile tarihiyle dursun, karar tarihi değerlidir.
- **`Context.md` = ŞU AN** (güncellenir). Projenin o anki hali: durum, nerede kaldık, sıradaki adım, açık sorular, Bitiş Çizgisi. **Gerekçeyi buraya kopyalama** — karara link ver: `Stack: Astro (bkz. Kararlar [2026-06-01])`. Böylece neden tek yerde durur, dosyalar birbirinden kaymaz.

## PRD disiplini

- **Kapsam bekçiliği:** bir istek geldiğinde PRD'nin Kapsam Dışı bölümüyle çelişiyorsa sessizce yapma — "bu PRD'de kapsam dışıydı, bilinçli mi genişletiyoruz?" diye sor. Bilinçliyse aşağıdaki değişiklik yolunu işlet.
- **Yön/kapsam değişirse:** gerekçe `Kararlar.md`'ye yazılır, PRD'nin **Değişiklik Notları** bölümüne tarihli tek satır düşülür (ne değişti + Kararlar linki). PRD gövdesini sessizce yeniden yazma — spec'in tarihi de bilgidir.
- **"Bitti mi?" tartışması:** PRD'deki Kabul Kriterleri'ne ve Context'teki Bitiş Çizgisi'ne bak. Kriterler sağlanmadan "bitti" deme; sağlananları Context'te işaretle.

## Yeni özellik geldiğinde — mini-PRD döngüsü

Kullanıcı anlamlı yeni bir özellik/kapsam istediğinde doğrudan koda başlama. Kurulumdaki sorgulama protokolünü özellik ölçeğinde işlet:
1. Özelliği açık uçlu anlat(tır), belirsiz noktaları `AskUserQuestion` ile netleştir — **kritik kararlarda kaçış kapısı yok**: kullanıcı "sen karar ver" dese bile geri dönüşü zor kararları (teknoloji, veri modeli, kapsam sınırı) önerilen-şık-ilk-sırada seçimli soruya çevir; kullanıcı tek tıkla onaylasın.
2. Sonucu PRD'ye `## Ek — [özellik adı] (tarih)` bölümü olarak yaz: kısa problem/çözüm + kabul kriterleri + kapsam dışı.
3. Alınan kararları `Kararlar.md`'ye, yeni bitiş çizgisi maddelerini Context'e işle.

Küçük düzeltme/bugfix/rutin iş için bu döngü gerekmez — normal plan-onay akışı yeter.

## Her şey potansiyel kaynak

Kaynak = her şey: aramızdaki konuşmalar, getirilen dosyalar (PDF, URL, makale, döküman), laf arasında geçen tercihler, tepkiler, "bunu beğendim / bu yaklaşımdan vazgeçiyoruz" gibi ifadeler, tekrar eden örüntüler. Hangi formatta gelirse gelsin, anlamlı her girdi beyne işlenir — izin beklemeden.

## Çelişki çıktığında — ikiye ayır

- **Olgu yanlış çıktıysa** (kesin bir bilgi düzeltmesi, örn. "API limiti 100 sandık, aslında 1000"): üzerine yaz, eskiyi sil.
- **Yön/strateji henüz netleşmemişse** (hâlâ tartışmalı): silme — yarışan halleri tarihle birlikte tut ("şu an X'e meyilliyiz ama Y hâlâ masada"). Netleşince tek doğruya indir, gerekçeyi `Kararlar.md`'ye yaz.
- İstisna: `Kararlar.md`'deki "denedik olmadı" tarihi hiç silinmez — o da bilgidir.

## Dış kaynak ingest — bilgi kopyalanmaz, işaret edilir

Brain, projenin durumu ve kararlarıdır; **bilgi deposu DEĞİLDİR.** Kaynak geldiğinde önce türüne karar ver:

**A) Karar besleyen kaynak** — makale, müşteri brief'i, analiz, karşılaştırma; bir kez okunup karara/yöne dönüşen şey:
1. Kaynağı oku → çıkarımı ilgili sayfaya entegre et; yoksa yeni sayfa aç (linkleme kuralı geçerli).
2. `Context.md`'ye not düş: hangi kaynak işlendi, hangi sayfa güncellendi.
3. Ham kaynağı beyne kaydetme — sadece çıkarılan bilgiyi. (Ham dosya repoda veya dışarıda durabilir.)

**B) Referans malzemesi** — eğitim wiki'si, prompt kütüphanesi, API dökümanı, reçete/ayar koleksiyonu; iş sırasında tekrar tekrar **aslına** bakılması gereken şey:
- Brain'e SENTEZLEME, KOPYALAMA. Sentez = kayıplı sıkıştırma; prompt/ayar/reçete gibi birebir korunması gerekenler özetlenince değerini kaybeder, üstelik kaynak güncellenince kopya sessizce eskir. (Denendi, olmadı: Görsel Üretim projesi, 2026-06 — eğitim brain'e sentezlendi, promptlar sadeleşip bozuldu; çözüm kaynağı yerinde bırakıp işaret etmek oldu.)
- Bunun yerine `Context.md`'ye (veya konu derinse kendi alt sayfasına) **işaret** bırak: kaynağın tam yolu + "hangi iş için, ne zaman oku" notu. İş anında kaynağın kendisinden oku.
- **İstisna:** küçük ve kesin olgular (API limiti, tek bir ayar değeri) brain'e yazılabilir. Kaynaktan bir parça almak şartsa **birebir + kaynak yoluyla** al, asla kendi cümlelerinle yeniden yazma.

## Beyin güncellemesi — oturum kapanmadan

Anlamlı her alışverişten sonra beyni güncelle. "Güncelleyeyim mi?" diye sorma — doğrudan yap. İyi bir analiz, keşif, çözülen sorun sohbette kaybolmaz, beyne yazılır. Yalnızca geri dönüşsüz işten önce sor: silme, birleştirme, büyük taşıma.

## Linkleme — çift yönlü, zorunlu

Yeni sayfa açılınca aynı anda:
1. `Context.md` → `## Alt Sayfalar`'a `[[Sayfa-Adı]] — ne içerir` ekle
2. Yeni sayfanın altına geri link: `[[Context]] — ana hub`
3. Aynı konuya değinen mevcut sayfa varsa karşılıklı link.

**Orphan yasak.** Hiçbir sayfa başka bir sayfadan linklenmeden var olamaz — lint'te öksüz sayfa ya linklenir ya silinir.

## Sayfa tipleri — içerik hak edince

Başta `PRD.md` + `Context.md` + `Kararlar.md`. Proje büyüdükçe gerekeni aç (boş açma):

| Sayfa | Ne zaman | Ne içerir |
|---|---|---|
| `Mimari.md` | Sistem karmaşıklaşınca | Veri akışı, component ilişkileri, diyagram |
| `Entegrasyonlar.md` | Dış servis eklenince | Endpoint, auth, limit, notlar |
| `Bug-Defteri.md` | Aynı hata 2+ kez çıkınca | Bilinen sorun, geçici çözüm, kök neden |
| `Arastirma-[Konu].md` | Derin dalış yapılınca | Karşılaştırma, analiz, sonuç |
| `Roadmap.md` | Uzun vade netleşince | Milestone, öncelik, bağımlılık |

Her alt sayfa minimal:
```
# [Sayfa Adı]
**Açıldı:** [YYYY-AA-GG] · **Bağlı:** [[Context]]

[içerik]

---
[[Context]] — ana hub
```

## /kapat — oturumu kapat

Kullanıcı `/kapat` derse:
1. `brain/Context.md`'yi güncelle (durum, nerede kaldık, sıradaki adım, açık sorular, Bitiş Çizgisi'nde tamamlananları işaretle).
2. Gerekçe doğuran bir şey olduysa `brain/Kararlar.md`'ye ekle; kapsam değiştiyse PRD Değişiklik Notları'na tarihli satır düş.
3. **Sadece beyni commit + push et:** `git add brain/ && git commit -m "session: [kısa özet]" && git push`. Kodu otomatik commit'leme — o kullanıcıya kalır.

## Kurallar

- **Her görevde önce plan, sonra uygulama.** Kullanıcı bir iş tarif edince direkt aksiyona geçme — önce ne yapacağını adım adım yaz, kullanıcıya sun, onay gelince başla. Onay gelmeden tek satır üretme, tek dosya değiştirme. (Anlamlı yeni özellikse plan da yetmez — mini-PRD döngüsü işler.)
- **Kod git'te, akıl `brain/`'de.** Kodun kendisi repoya; hedef/neden/durum beyne.
- **Bilgi kopyalanmaz, işaret edilir.** Brain bilgi deposu değildir — referans malzemesi (eğitim, prompt kütüphanesi, döküman) kaynağında kalır, brain'e sadece yol + "ne zaman oku" notu düşülür. Birebir korunması gereken şey (prompt, ayar, reçete) asla özetlenerek taşınmaz.
- **Her anlamlı değişiklikten sonra push.** Bir görev tamamlanınca — kullanıcı onaylayıp iş bitince — `git add`, `git commit`, `git push` yap. Değişiklik yarım kalmış veya onaysız ise push etme. Push'u kullanıcıya sormadan yap; sadece büyük/kırıcı değişiklik öncesinde sor.
- **Boş sayfa açma** — `PRD` + `Context` + `Kararlar` yeter, gerisi içerik hak edince doğar.
- **Beyin commit'leri otomatik, kod commit'leri kullanıcıya ait.**

## Büyüme ve bakım

`Context.md` = sıcak hub. Bir konu derinleşip Context'i şişirince kendi alt sayfasına ayrılır, Context'ten `[[linklenir]]`. O konu sorulunca yalnız o sayfa okunur — tüm beyin değil.

**Lint:** oturum başında `Context.md`'deki **Son lint** tarihine bak; ~2 hafta geçtiyse veya kullanıcı "lint at" derse → eskimiş bilgi, kopuk link, öksüz sayfa, PRD-Context tutarlılığı (Bitiş Çizgisi güncel mi, kapsam kaymış mı), sorulması gereken sorular. Bitince tarihi güncelle.

`Kararlar.md` yüzlerce satıra ulaşırsa yıla böl: `Kararlar-2026.md`, `Kararlar-2027.md`. Eskiyi Context'ten linkle.

## Bu dosya yaşayan bir belgedir

Neyin işlediğini gördükçe bu `Claude.md`'yi güncelle. Bir kural saçmalıyorsa değiştir, eksik varsa ekle. Taşa kazınmış değil — sistemin kendisi de öğrenir.
