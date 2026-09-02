# LISTENDER — Karar Günlüğü

> NEDEN'in tek evi. Append-only. Her karar: tarih + ne + neden (+ varsa "denedik olmadı"). Eskiler silinmez.

## [2026-09-02] Python'dan Swift'e — motor whisper.cpp değil WhisperKit

**Ne:** Uygulama sıfırdan Swift/AppKit ile yeniden yazıldı (Droper'ın paket düzeni:
`ListenderKit` kütüphanesi + ince executable). Whisper motoru olarak **WhisperKit**
(CoreML) seçildi, model `openai_whisper-large-v3-v20240930_turbo`.

**Neden whisper.cpp değil — araştırıldı, kapalı çıktı:** whisper.cpp SwiftPM desteğini
bırakmış. Son manifest v1.7.4'te ve o da `.systemLibrary` — yani `brew install whisper-cpp`
ile ayrıca kurulum ve pkg-config gerektiriyor. v1.7.6 ve sonrasında (güncel v1.9.3)
`Package.swift` hiç yok, hazır xcframework de release'lerde yayınlanmıyor. Kalan yollar
(kaynağı repoya gömmek, kurulumda CMake ile derlemek) tek başına birer proje.

**WhisperKit ölçüldü (M2 Pro, 16 GB):** 6 saniyelik Türkçe ses **0,8 saniyede** ve
kusursuz çözülüyor. PRD 5-10 saniyelik dikteyi 2 saniyede istiyordu, rahat geçiyor.

**Yan fayda:** ggml model dosyası yerine CoreML kullanıldığı için Neural Engine devrede.

## [2026-09-02] WhisperKit'te `prewarm: true, load: true` ŞART

**Ne:** `WhisperKitConfig`'te bu iki bayrak açık.

**Neden — ölçüldü:** Bayraklar olmadan `tiny` model 6 saniyelik sesi **8 saniyede**
çözüyordu, `large-v3-turbo` ise **135 saniyede**. Bayraklar açıkken aynı ses sırasıyla
**0,18** ve **0,83** saniye. Yani modeli önden yükletmezsen çözme çağrısının içinde
yükleniyor ve her şey CPU hızına düşüyor. Uygulamanın "model açılışta bir kez yüklenir,
sıcak tutulur" tasarımı zaten bunu gerektiriyordu; ölçüm bunu sayıyla doğruladı.

## [2026-09-02] `initial_prompt` karşılığı KULLANILAMIYOR — kaldırıldı

**Ne:** Python sürümü noktalama tutarlılığı için whisper'a örnek cümle (`initial_prompt`)
veriyordu. Swift sürümünde bu yok.

**Neden — denedik olmadı:** WhisperKit'te karşılığı `DecodingOptions.promptTokens`.
Verilince **transkript boş dönüyor**. Sebep WhisperKit'in kendi kaynağında not düşülmüş
(`TextDecoder.swift`: "allow prefill cache to be used with prompt tokens, currently breaks
if it starts at non-zero index") — prompt ile prefill önbelleği birlikte çalışmıyor.
Özel token süzme değil (onu WhisperKit zaten yapıyor), yapısal bir uyumsuzluk.

**Sonuç:** Gerek de kalmadı — large-v3-turbo kendiliğinden düzgün noktalıyor
("Bugün müşteriyle görüştük, sipariş onaylandı."). WhisperKit bunu düzeltirse yeniden bakılır.

## [2026-09-02] Türkçe küçük harf: `lowercased()` YETMİYOR (sessiz bug)

**Ne:** `Temizleyici.turkceKucult` ve `turkceDesen` yazıldı; halüsinasyon karşılaştırması
ve dolgu desenleri bunları kullanıyor.

**Neden:** Swift'in (ve Python'un) `lowercased()`'i İngilizce kuralı uygular: "İ" harfini
"i" + birleşen nokta (U+0307) yapar, "I" harfini de "ı" değil "i" yapar. Bu yüzden
halüsinasyon filtresi cümle başındaki büyük harfli kalıpları ("İzlediğiniz için teşekkür")
**hiç yakalamıyordu** — whisper çıktısı tam da böyle büyük harfle başlıyor.
`caseInsensitive` regex bayrağı da i/ı çiftini doğru eşleştirmiyor, o yüzden desenler
her harfin Türkçe büyük karşılığını da kabul edecek şekilde üretiliyor.

**Not:** Aynı kusur Python sürümünde de vardı, kimse fark etmemişti; Swift'e geçerken
yazılan test yakaladı.

## [2026-09-02] Bağımlılık kaynak paketleri .app'e KOPYALANMIYOR

**Ne:** `make-app.sh` `.build/release/*.bundle` dosyalarını pakete koymuyor.

**Neden:** İki tane var — swift-crypto'nunki yalnız bir gizlilik bildirimi,
swift-transformers'ınki kullanılmayan gpt2/t5 tokenizer yedekleri. SwiftPM'in erişimcisi
onları `Bundle.main.bundleURL/<ad>.bundle` yolunda arıyor, yani .app'in kökünde; oraya
konunca `codesign` "unsealed contents present in the bundle root" deyip **imzayı geçersiz
kılıyor** (doğrulama exit 1). İmza geçersiz olunca da macOS izinleri (Giriş İzleme,
Erişilebilirlik) güvenilmez hale gelir — bu uygulama için kabul edilemez.
`Contents/Resources/`'a koymak işe yaramıyor, erişimci orayı aramıyor.

**Deneyle çözüldü:** Binary tek başına, yanında hiçbir paket yokken geçici bir klasöre
kopyalanıp `listender-ses-testi` ile koşturuldu — model yükleme ve transkript sorunsuz.
Yani bu paketlere çalışma anında hiç dokunulmuyor. Kopyalanmıyorlar, imza geçerli.

## [2026-09-02] Teşhis logu /tmp'den kullanıcı klasörüne taşındı

**Ne:** Log artık `~/Library/Logs/Listender/listender.log`. Ayrıca dikte metninin kendisi
varsayılan olarak loglanmıyor (`Gunluk.metin` yalnız karakter sayısını yazar).

**Neden:** 2026-07-23 kod denetiminin gizlilik bulgusu: dikte edilen metinler
`/tmp/listender.log` dosyasına yazılıyordu ve `/tmp` makinedeki herkese açık.


## [2026-07-03] Paketli .app'te Python UTF-8 modu ZORUNLU (dikteyi öldüren bug)

**Ne:** Üç katman: (1) plist `LSEnvironment: {PYTHONUTF8: "1"}` — bundle'daki tüm Python UTF-8 modunda, (2) `/tmp/listender.log` `encoding="utf-8", errors="replace"` ile açılır, (3) Ollama subprocess'i `encoding="utf-8"`.
**Neden — denedik olmadı (encoding belirtmeden):** Finder'dan açılan .app'te locale C/ASCII'dir (terminaldeki gibi UTF-8 değil; terminal testinde üretilemedi çünkü shell'de Python C-locale'i otomatik UTF-8'e çevirir — Finder ortamında çevirmedi). Log dosyası encoding'siz açılınca `print("[dikte] kayıt…")` içindeki 'ı' harfi `UnicodeEncodeError` fırlattı → `_process` worker thread'i öldü → kayıt alınıyor ama metin asla yazılmıyordu. Hata mesajının kendisi de Türkçe karakter içerdiğinden except bloğu da çöktü — çifte sessiz ölüm. Türkçe uygulamada paketleme yaparken ilk bakılacak yer.
**Ders:** kanıt `/tmp/listender.log`'daki traceback'ti — bundled modda stdout/stderr'i log dosyasına yönlendirmek (run.py) bu teşhisi mümkün kıldı; yönlendirme kalıcı özellik olarak kaldı.

## [2026-07-03] Kurulum: tek-tık kur.command + model yolu Listender'un kendi klasörüne

**Ne:** `Kurulum/` klasörü: imzalı `Listender.app` + `kur.command` (çift tık → karantina kaldır + /Applications'a taşı + izin panellerini aç + başlat). Model yolu: VidScribe kopyası VARSA paylaşılır, yoksa `~/Library/Application Support/Listender/models/`'a iner — dağıtılan .app yabancı makinede VidScribe klasörü oluşturmasın.
**Neden:** README'deki elle adımlar (xattr + taşı + üç izin paneli) kullanıcıyı yordu; canlı kurulumda izin panellerinde kaybolma yaşandı. Tek komutluk script "en az uğraş" hedefini ancak yarı karşıladı — çift tıklık kur.command tam karşılıyor. İzin doğrulaması: TCC db dışarıdan okunamıyor (Full Disk Access ister); tek güvenilir teşhis uygulamanın kendi logu ("This process is not trusted" satırı = Giriş İzleme yok; "[mikrofon] stream açıldı" = mikrofon tamam).
**Doğrulama (2026-07-03):** Paketli .app ile uçtan uca canlı dikte GEÇTİ — kayıt → transkript → temizlik → enjeksiyon, Türkçe karakterler dahil. Not: mikrofon izni Giriş İzleme/Erişilebilirlik'ten AYRI ve ilk stream açılışında sorulur; verici kapalı mikrofon (şarj bitmesi) 🚫 ikonuyla karışabiliyor.

## [2026-07-03] v2 Paketleme: ad-hoc imzasız .app + tek komutluk karantina-kaldırma

**Ne:** İndirilebilir uygulama py2app ile **ad-hoc imzalı (`codesign -s -`) .app** olarak paketlenir, GitHub release'ine `.zip`/`.dmg` konur. İmzalı+notarize .app yolu seçilmedi. Gatekeeper duvarı, README'deki tek satırlık komutla (`xattr -dr com.apple.quarantine`) aşılır. Whisper modeli .app dışında, ilk açılışta iner; Ollama/LLM indiren PC'de yerel çekilir; kullanıcının API anahtarı .app'e GÖMÜLMEZ.
**Neden:** Kullanıcının Apple Developer hesabı yok ($99/yıl alınmayacak) → notarize edilmiş temiz .app mümkün değil. İmzasız .app + herkese açık GitHub dağıtımı = Gatekeeper "geliştirici doğrulanamadı" duvarı kaçınılmaz; kullanıcıyı en az uğraştıran dürüst çözüm = README'de tek komut (sağ tık→Aç yöntemi macOS Sequoia'da Sistem Ayarları'ndan ek onay isteyebildiği için elendi). "Tam yerel, ses/veri makineden çıkmaz" felsefesi gereği kullanıcının kendi API anahtarı dağıtılmaz — her indiren kendi LLM'ini çeker.
**İzin tuzağı (bkz. [2026-07-03] izin stratejisi):** TCC izni çağıran binary'ye bağlanır. .app bundle binary yolu sabit olduğundan izinler .app'e bir kez verilip kalıcı olur — v1 launcher tuzağının .app karşılığı çözümü. Ad-hoc imza her build'de değişebildiğinden yeniden-build sonrası izinlerin tekrar istenmesi bilinen risk; kullanım sırasında test edilecek.

## [2026-07-03] Proje kuruldu — PRD yazıldı ✅

**Mod:** hızlı · **Stack:** Python 3 (pywhispercpp, sounddevice, pynput, rumps, pyobjc)  
**Neden:** Mevcut VidScribe Whisper motoru Python'da — uyum ve kod yeniden kullanımı. En olgun açık kaynak klonlar (Handy/Rust, VoiceInk/Swift) native'e geçmiş olsa da, inference zaten whisper.cpp'ye (native) delege edildiği için Python orkestrasyon katmanı olarak yeterli; `savbell/whisper-writer` bunun çalışan kanıtı.

## [2026-07-03] STT: pywhispercpp + large-v3-turbo, dil sabit Türkçe

**Ne:** whisper.cpp (Metal) üzerinden `large-v3-turbo`; `language="tr"` sabit, otomatik dil algılama yok. VidScribe'ın model dosyası paylaşılır, yeniden indirilmez. Model açılışta bir kez yüklenir, bellekte sıcak tutulur.  
**Neden:** Türkçe'de `small` isabetsiz (WER ~%17), turbo large doğruluğunda + medium hızında; M4'te 5-10 sn dikte ~1 sn. Kullanıcı yalnız Türkçe dikte edecek — sabit dil hem hız hem yanlış algılama riskini sıfırlar. VidScribe'daki her-çağrıda-model-yükleme deseni dikte gecikmesine uymaz — elendi. faster-whisper Mac'te GPU kullanamıyor — elendi.

## [2026-07-03] Tetikleme: bas-konuş, sağ Option (⌥)

**Ne:** Sağ Option basılı tut = kayıt, bırak = transkript + yaz. pynput global listener.  
**Neden:** Tuş = kayıt sınırı → VAD gerekmez, en basit ve sağlam akış. Fn/Globe (Wispr varsayılanı) macOS tarafından rezerve — sistem ayarı + Quartz event tap kırılganlığı nedeniyle elendi. Toggle mod v2'ye ertelendi (kapsam dışı).

## [2026-07-03] Metin enjeksiyonu: pano + Cmd-V, geri yükleme ile

**Ne:** NSPasteboard içeriğini kaydet → metni koy → CGEventPost ile Cmd-V → ~300 ms → eski panoyu geri yükle.  
**Neden:** En hızlı ve Türkçe karakterlerde en güvenilir yöntem; Handy/VoiceInk/FreeFlow fiilen bunu kullanıyor. Karakter karakter klavye simülasyonu (pynput type) macOS'ta Türkçe/büyük harf sorunları nedeniyle elendi; AX API (setValue) Electron/web uygulamalarda güvenilmez — elendi.

## [2026-07-03] Temizlik katmanı: regex + opsiyonel Ollama Qwen3 4B

**Ne:** Whisper çıktısına önce deterministik regex dolgu temizliği; Ollama erişilebilirse `qwen3:4b` ile noktalama/akıcılık düzeltmesi ("anlamı değiştirme" promptu). Ollama yoksa/kapalıysa sessizce regex-only.  
**Neden:** Whisper dolguları ("eee/yani/hani") silmez. Wispr Flow'un kalite farkı LLM post-process'ten geliyor — kullanıcı bu kaliteyi istedi, Ollama kurulumunu kabul etti (makinede yoktu). Qwen3 4B: 16 GB RAM'de whisper ile yan yana çalışır, M4'te ~0.5-1 sn ek gecikme. Regex fallback = LLM tek hata noktası olmasın.

## [2026-07-03] İzin stratejisi: sabit launcher

**Ne:** Mikrofon + Input Monitoring + Accessibility izinleri hep aynı sabit binary/launcher üzerinden verilir; py2app paketleme v2'ye bırakıldı.  
**Neden:** macOS TCC izni koda değil çağıran binary'ye bağlar — venv/python değişince izinler sessizce bozulur (bilinen tuzak). Sabit launcher bunu ucuza çözer; imzalı .app daha temiz ama v1 için gereksiz yük.

## [2026-07-03] Mikrofon hot-plug: yoksa çalışma, takılınca otomatik gel

**Ne:** Açılışta mikrofon yoksa uygulama çökmz — 🚫 ikonu + "bağlanınca hazır olur" durumu gösterir, bas-konuş devre dışı kalır. `rumps.Timer` her 2 sn `sd._terminate()/_initialize()` ile aygıt cache'ini tazeleyip yoklar; mikrofon takılınca stream'i açıp otomatik hazır olur, çekilince tekrar bekleme durumuna döner.
**Neden:** Bu makine (Mac mini) dahili mikrofonsuz; giriş aygıtı sonradan (USB/kamera) bağlanıyor. Kullanıcı "mikrofon bağlı değilse program çalışmasın, bağlanınca otomatik gelen kanalla çalışsın" dedi. sounddevice aygıtları ilk sorguda cache'lediği için çalışırken takılan mikrofon yeniden başlatmadan görünmez → cache tazeleme şart.

## [2026-07-03] Hot-plug yoklaması: stream açıkken PortAudio'ya dokunulmaz

**Ne:** `_poll_mic` iki moda ayrıldı — mikrofon yokken `refresh_devices()` (cache tazele) + ara; mikrofon varken sadece callback-akışı sağlık kontrolü (`stream_alive()`). Ek olarak transkript öncesi peak normalizasyon + RMS sessizlik kapısı eklendi.
**Neden — denedik olmadı (her poll'da refresh):** `sd._terminate()/_initialize()` aktif InputStream'i sessizce öldürüyor (repro: refresh öncesi 66 callback/2sn, sonrası 0). Uygulama açıldıktan 2 sn sonra mikrofon fiilen kopuyordu — canlı testteki "kayıt 0.5 sn + RMS≈0" bug'ının kök nedeni. Callback zaman damgası hem stream ölümünü hem fiziken çekilen mikrofonu tek mekanizmayla yakalar. Normalizasyon: kablosuz mikrofon kısık gelebiliyor (konuşma RMS ~0.009); sessizlik kapısı: verici kapalıyken normalize edilmiş gürültü whisper'da halüsinasyon üretir.

## [2026-07-03] UI güncellemeleri yalnızca ana thread'den (AppHelper.callAfter)

**Ne:** Tüm AppKit dokunuşları (`status_item.title`, menü barı ikonu) `AppHelper.callAfter` köprüsüyle ana thread'e taşındı (`_set_status`/`_set_title`).
**Neden — denedik olmadı (doğrudan atama):** Worker thread'den `NSMenuItem.setTitle` menü açıkken SIGTRAP crash üretti (canlıda yaşandı, crash raporuyla teşhis edildi). macOS kuralı: UI'a sadece ana thread dokunur; "kısa atama güvenli" varsayımı yanlış.

## [2026-07-03] LLM temizliği #2: qwen2.5:3b elendi → qwen3:4b-instruct + few-shot, varsayılan yine KAPALI

**Ne:** Model qwen2.5:3b-instruct → `qwen3:4b-instruct` (thinking'siz 2507 sürümü, Ollama'dan indirildi). Prompt talimat-içi örneklerden **few-shot formatına** çevrildi (örnekler ayrı user/assistant mesajları, `config.LLM_FEWSHOT`). Varsayılan KAPALI kaldı.
**Neden — denedik olmadı (qwen2.5:3b + prompt iyileştirme):** İki tur prompt mühendisliği yetmedi: sistem promptundaki örnekler çıktıya sızdı ("Görüştük..." vakası — canlı dikteye karıştı), Çince karakter üretti ("Ol拉馬"), kişi kaydırdı ("güncelledim→güncellendirdim"). Talimat-içi örnek küçük modellerde zehirli → few-shot şart.
**qwen3:4b-instruct + few-shot (8 örnekli test):** Açık ara en iyi — dolgu temizliği doğru, marka adları korunur (CapCut, WhatsApp), ~0.6 sn. AMA hâlâ güvenilmez: "verdim→verildi" (kişi), "bulunmaktayız→bulunuyoruz" (eş anlamlı), "sipariş→sipariış" (yazım). **Sonuç: 4B sınıfı yerel model dikte sadakati için yetersiz** — LLM varsayılan KAPALI, bilinçli kullanıcı menüden açar; açarsa eldeki en iyi model bu. Gelecek: 8B+ model denenebilir.

## [2026-07-03] LLM temizlik modeli: qwen3:4b → qwen2.5:3b-instruct, varsayılan KAPALI

**Ne:** LLM post-process modeli qwen3:4b'den qwen2.5:3b-instruct'a geçti; chat endpoint (`/api/chat`) + `keep_alive` kullanılıyor. LLM varsayılan olarak KAPALI başlıyor, menüden manuel açılır.
**Neden — denedik olmadı (qwen3:4b):** thinking modu kapatılamadı — `think:false` (hem generate hem chat), `/no_think` sistem promptu, `num_predict` sınırı hepsi denendi; model her koşulda İngilizce uzun reasoning yapıyor ("Okay, let's tackle this...") ve çağrı 60-130 sn sürüyor. `<think>` etiketi bile gelmediği için strip edilemiyor. Dikte için kabul edilemez → elendi.
**qwen2.5:3b-instruct:** reasoning yok, ısınınca ~0.6 sn (hedefe uygun). ANCAK anlamı bozabiliyor: "bugün"→"günümüz", "müşteriyle"→"müşterimize", "onayladı"→"onayladık". Prompt sıkılaştırması (zaman/kişi koru) yetmedi. Bu yüzden LLM şimdilik KAPALI; regex-only güvenilir varsayılan. Prompt mühendisliği veya daha büyük/uyumlu bir model sonraki oturuma bırakıldı. Regex katmanı test edildi, doğru çalışıyor.
