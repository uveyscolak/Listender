import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics

/// Menü barı uygulaması ve orkestrasyon.
///
/// Sağ ⌥ basılı tutulunca kayıt başlar, bırakılınca zincir işler:
/// transkript, temizlik, enjeksiyon. Durum menü barındaki ikonda görünür.
///
/// Durum yalnız ana aktörde tutulur (Python sürümündeki kilit ve
/// `AppHelper.callAfter` köprüsü böylece gereksiz kaldı).
@MainActor
public final class UygulamaDelegesi: NSObject, NSApplicationDelegate {

    // Durum ikonları
    private enum Ikon {
        static let bosta = "🎙️"
        static let yukleniyor = "⏳"
        static let kayit = "🔴"
        static let isleniyor = "✍️"
        static let mikrofonYok = "🚫"
        static let hata = "⚠️"
    }

    private let kaydedici = Kaydedici()
    private var cozumleyici: Cozumleyici!

    private var durumOgesi: NSStatusItem!
    private var durumSatiri: NSMenuItem!
    private var modelOgesi: NSMenuItem!
    private var llmOgesi: NSMenuItem!
    private var girisIzlemeOgesi: NSMenuItem!
    private var erisilebilirlikOgesi: NSMenuItem!
    private var mikrofonIzniOgesi: NSMenuItem!
    private var mikrofonSayaci: Timer?
    private var izinBekcisi: Timer?

    private var modelHazir = false
    private var modelYukleniyor = false
    private var mikrofonHazir = false
    private var kayitta = false
    private var kayitBasladi = Date()
    private var llmKullan = Ayarlar.llmVarsayilanAcik
    private var girisIzlemeVar = false
    private var erisilebilirlikVar = false

    private var tusDinleyici: TusDinleyici!

    public override init() {
        super.init()
    }

    // MARK: Açılış

    public func applicationDidFinishLaunching(_ notification: Notification) {
        menuyuKur()

        // Giriş İzleme (Input Monitoring) sistemden resmi API'yle istenir; aksi
        // halde uygulama izin listesinde hiç görünmüyor, kullanıcı "+" ile elle
        // eklemek zorunda kalıyor.
        let girisIzlemeOnceden = CGPreflightListenEventAccess()
        Gunluk.yaz("giriş izleme izni: \(girisIzlemeOnceden)")
        if !girisIzlemeOnceden {
            let istekSonucu = CGRequestListenEventAccess()
            Gunluk.yaz("giriş izleme izni istendi, sonuç: \(istekSonucu)")
        }

        // Erişilebilirlik güvenini resmi API'den iste: bu hem sistem uyarısını
        // gösterir hem de uygulamayı Erişilebilirlik listesine otomatik
        // düşürür — "+" ile elle ekleme gerekmez.
        let secenekler = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let guvenilirMi = AXIsProcessTrustedWithOptions(secenekler)
        Gunluk.yaz("erişilebilirlik güveni: \(guvenilirMi)")

        girisIzlemeVar = girisIzlemeOnceden
        erisilebilirlikVar = guvenilirMi
        izinMenusunuTazele()
        izinBekcisiKur()

        mikrofonIzniniIste()

        cozumleyici = Cozumleyici { [weak self] mesaj in
            Task { @MainActor in
                self?.durumYaz(mesaj)
                self?.modelOgesiniGuncelle(mesaj)
            }
        }

        tusDinleyici = TusDinleyici(
            basildi: { [weak self] in self?.kaydiBaslat() },
            birakildi: { [weak self] in self?.kaydiBitir() })
        tusDinleyici.izinSorunu = { [weak self] sorunVar in
            guard let self else { return }
            if sorunVar {
                self.girisIzlemeVar = false
                self.izinBekcisiKur()
                // Kayıt sürerken "Kayıt…" satırının üstüne yazma.
                if !self.kayitta { self.durumYaz("Giriş İzleme izni yok — İzinler menüsünden aç") }
            } else {
                self.bostaDurumunuTazele()
            }
        }

        do {
            try tusDinleyici.basla()
        } catch {
            durumYaz("Giriş İzleme / Erişilebilirlik izni gerekiyor")
            ikonYaz(Ikon.hata)
            Gunluk.yaz("tuş dinleyicisi kurulamadı: \(error.localizedDescription)")
        }

        // Model yükleme ağır: arayüzü bloklamasın.
        Task { await modeliYukle() }

        // Ollama kuruluysa servisi kaldır (kurulu değilse sessizce geçer).
        Task { await Ollama.kuruluysaBaslat(); await llmMenusunuTazele() }

        // Mikrofonu periyodik yokla: takılınca kendiliğinden hazır olsun,
        // çekilince bas-konuş devre dışı kalsın.
        mikrofonSayaci = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.mikrofonuYokla() }
        }
        mikrofonuYokla()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        mikrofonSayaci?.invalidate()
        izinBekcisi?.invalidate()
        tusDinleyici?.dur()
        kaydedici.akisiDurdur()
    }

    private func menuyuKur() {
        durumOgesi = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        durumOgesi.button?.title = Ikon.yukleniyor

        let menu = NSMenu()
        durumSatiri = NSMenuItem(title: "Başlatılıyor…", action: nil, keyEquivalent: "")
        durumSatiri.isEnabled = false
        menu.addItem(durumSatiri)

        modelOgesi = NSMenuItem(
            title: "Model: hazırlanıyor…",
            action: #selector(modeliYenidenYukle), keyEquivalent: "")
        modelOgesi.target = self
        modelOgesi.isEnabled = false
        menu.addItem(modelOgesi)
        menu.addItem(.separator())

        llmOgesi = NSMenuItem(
            title: "Ollama ile metin düzeltme — kapalı",
            action: #selector(llmDegistir), keyEquivalent: "")
        llmOgesi.target = self
        menu.addItem(llmOgesi)

        let llmAciklama = NSMenuItem(
            title: "Noktalama ve akıcılığı düzeltir; Ollama ayrı kurulur",
            action: nil, keyEquivalent: "")
        llmAciklama.isEnabled = false
        menu.addItem(llmAciklama)
        menu.addItem(.separator())

        let izinlerMenu = NSMenu()
        girisIzlemeOgesi = NSMenuItem(
            title: "Giriş İzleme", action: #selector(girisIzlemePaneliniAc), keyEquivalent: "")
        girisIzlemeOgesi.target = self
        izinlerMenu.addItem(girisIzlemeOgesi)

        erisilebilirlikOgesi = NSMenuItem(
            title: "Erişilebilirlik", action: #selector(erisilebilirlikPaneliniAc), keyEquivalent: "")
        erisilebilirlikOgesi.target = self
        izinlerMenu.addItem(erisilebilirlikOgesi)

        mikrofonIzniOgesi = NSMenuItem(
            title: "Mikrofon", action: #selector(mikrofonPaneliniAc), keyEquivalent: "")
        mikrofonIzniOgesi.target = self
        izinlerMenu.addItem(mikrofonIzniOgesi)

        let izinler = NSMenuItem(title: "İzinler", action: nil, keyEquivalent: "")
        izinler.submenu = izinlerMenu
        menu.addItem(izinler)
        menu.addItem(.separator())

        let nasilCalisir = NSMenuItem(
            title: "Nasıl çalışır…", action: #selector(nasilCalisirGoster), keyEquivalent: "")
        nasilCalisir.target = self
        menu.addItem(nasilCalisir)

        let cikis = NSMenuItem(title: "Çıkış", action: #selector(cik), keyEquivalent: "q")
        cikis.target = self
        menu.addItem(cikis)

        durumOgesi.menu = menu
    }

    // MARK: Model

    private func modeliYukle() async {
        guard !modelYukleniyor else { return }
        modelYukleniyor = true
        modelOgesi.title = "Model: hazırlanıyor…"
        modelOgesi.isEnabled = false

        do {
            try await cozumleyici.yukle()
            modelHazir = true
            modelYukleniyor = false
            modelOgesi.title = "Model: hazır"
            modelOgesi.isEnabled = false
            bostaDurumunuTazele()
        } catch {
            Gunluk.yaz("model yüklenemedi: \(error.localizedDescription)")
            durumYaz("Model hatası: \(error.localizedDescription)")
            ikonYaz(Ikon.hata)
            modelYukleniyor = false
            modelOgesi.title = "Model inmedi — yeniden indir"
            modelOgesi.isEnabled = true
        }
    }

    /// Cozumleyici'nin yükleme sürecinde ilettiği ilerleme metnine göre menüdeki
    /// model satırını günceller ("indiriliyor" mu "hazırlanıyor" mu). Yükleme
    /// bitince (başarı ya da hata) `modeliYukle()` son hâli kendisi yazar.
    private func modelOgesiniGuncelle(_ mesaj: String) {
        guard modelYukleniyor else { return }
        modelOgesi.title = mesaj.contains("indiriliyor") ? "Model: indiriliyor…" : "Model: hazırlanıyor…"
    }

    @objc private func modeliYenidenYukle() {
        Task { await modeliYukle() }
    }

    private var hazirMi: Bool { modelHazir && mikrofonHazir }

    // MARK: Mikrofon izni

    /// Mikrofon iznini açıkça iste ve durumu kaydet.
    ///
    /// Kritik: izin verilmemişse macOS **hata vermez** — AVAudioEngine sorunsuz
    /// başlar, tap düzenli çalışır, ama bütün örnekler sıfırdır (RMS=0.0000).
    /// Bu yüzden izin durumu açıkça sorulmazsa arıza "sessiz mikrofon" gibi
    /// görünür ve teşhis edilemez. 2026-09-03'te tam olarak bu yaşandı.
    private func mikrofonIzniniIste() {
        let durum = AVCaptureDevice.authorizationStatus(for: .audio)
        Gunluk.yaz("mikrofon izni: \(izinAdi(durum))")

        switch durum {
        case .authorized:
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] verildi in
                Task { @MainActor in
                    Gunluk.yaz("mikrofon izni istendi, sonuç: \(verildi)")
                    guard let self else { return }
                    if verildi {
                        // Akış izin gelmeden açılmış olabilir; o akış sıfır dolu
                        // tampon taşır ve izin sonradan verilse de kendiliğinden
                        // düzelmez. Kapatıp yeniden kurulmalı.
                        Gunluk.yaz("izin sonrası ses akışı yeniden kuruluyor")
                        self.kaydedici.akisiDurdur()
                        self.mikrofonHazir = false
                        self.mikrofonuYokla()
                    } else {
                        self.mikrofonIzniYokUyar()
                    }
                }
            }
        case .denied, .restricted:
            mikrofonIzniYokUyar()
        @unknown default:
            return
        }
    }

    private func mikrofonIzniYokUyar() {
        durumYaz("Mikrofon izni yok — Gizlilik → Mikrofon")
        ikonYaz(Ikon.hata)
        Gunluk.yaz("mikrofon izni verilmemiş: ses sessiz gelecek")
    }

    private func izinAdi(_ durum: AVAuthorizationStatus) -> String {
        switch durum {
        case .authorized: return "verilmiş"
        case .denied: return "REDDEDİLMİŞ"
        case .restricted: return "KISITLI"
        case .notDetermined: return "henüz sorulmamış"
        @unknown default: return "bilinmiyor"
        }
    }

    // MARK: Mikrofon yoklama

    private func mikrofonuYokla() {
        guard !kayitta else { return }

        if mikrofonHazir {
            // Akış canlı mı: mikrofon fiziken çekilince motor hata vermeden susar,
            // tek güvenilir işaret tap akışının durmasıdır.
            if !kaydedici.akisCanli() {
                Gunluk.yaz("mikrofon akışı durdu — kapatılıyor")
                mikrofonHazir = false
                kaydedici.akisiDurdur()
                bostaDurumunuTazele()
            }
            return
        }

        guard Kaydedici.girisAygitiVarMi() else { return }
        do {
            try kaydedici.akisiBaslat()
            mikrofonHazir = true
            bostaDurumunuTazele()
        } catch {
            mikrofonHazir = false
        }
    }

    // MARK: Kayıt

    private func kaydiBaslat() {
        guard hazirMi, !kayitta else { return }
        kayitta = true
        kayitBasladi = Date()
        kaydedici.kaydiBaslat(sinirAsildi: { [weak self] in
            Task { @MainActor in self?.kaydiBitir() }
        })
        ikonYaz(Ikon.kayit)
        durumYaz("Kayıt… (bırakınca yazılır)")
    }

    private func kaydiBitir() {
        guard kayitta else { return }
        kayitta = false
        let ses = kaydedici.kaydiBitir()
        let sure = Date().timeIntervalSince(kayitBasladi)
        ikonYaz(Ikon.isleniyor)

        // Halüsinasyon filtresi: çok kısa basmalarda hiçbir şey yapma.
        guard sure >= Ayarlar.enKisaKayitSaniye, !ses.isEmpty else {
            bitir("Çok kısa — atlandı")
            return
        }
        Task { await isle(ses) }
    }

    private func isle(_ ses: [Float]) async {
        let rms = rmsHesapla(ses)
        Gunluk.yaz(String(format: "kayıt %.1f sn, %d örnek, RMS=%.4f",
                          Double(ses.count) / Ayarlar.ornekleme, ses.count, rms))

        // Sessizlik kapısı: sinyal yoksa whisper'a hiç gitme, normalize edilmiş
        // gürültü halüsinasyon üretir.
        guard rms >= Ayarlar.sessizlikRMS else {
            // Tam sıfır, "kısık mikrofon"dan farklı bir arızadır: izin verilmemiş
            // mikrofonda macOS hata vermeden sıfır dolu tampon gönderir. İkisini
            // ayırıp kullanıcıya doğru yeri göster.
            if rms == 0, AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
                Gunluk.yaz("kayıt tamamen sessiz ve mikrofon izni yok — izin sorunu")
                bitir("Mikrofon izni yok — Gizlilik → Mikrofon")
            } else {
                bitir("Ses yok — mikrofon açık mı?")
            }
            return
        }

        do {
            durumYaz("Yazıya çevriliyor…")
            let ham = try await cozumleyici.cozumle(ses)
            Gunluk.metin("ham transkript", ham)
            guard !ham.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                bitir("Boş — bir şey duyulmadı")
                return
            }

            durumYaz("Temizleniyor…")
            let metin = await Temizleyici.temizle(ham, llmKullan: llmKullan)
            Gunluk.metin("temiz metin", metin)
            guard !metin.isEmpty else {
                bitir("Temizlik sonrası boş")
                return
            }

            switch Enjektor.enjekteEt(metin) {
            case .yazildi:
                bitir("Yazıldı: \(onizleme(metin))")
            case .izinYokPanodaBirakildi:
                bitir("İzin yok — metin panoda, Cmd-V ile yapıştır")
            case .bosMetin:
                bitir("Boş metin")
            }
        } catch {
            Gunluk.yaz("dikte hatası: \(error.localizedDescription)")
            bitir("Hata: \(error.localizedDescription)")
        }
    }

    private func onizleme(_ metin: String) -> String {
        metin.count <= 40 ? metin : String(metin.prefix(37)) + "…"
    }

    // MARK: LLM menüsü

    @objc private func llmDegistir() {
        if llmKullan {
            llmKullan = false                 // kapatma her zaman serbest
            Task { await llmMenusunuTazele() }
            return
        }
        Task { await llmAcmayiDene() }
    }

    private func llmAcmayiDene() async {
        if await Ollama.kullanilabilir() {
            llmKullan = true
            await llmMenusunuTazele()
            return
        }

        guard Ollama.binaryYolu() != nil else {
            let uyari = NSAlert()
            uyari.messageText = "Ollama kurulu değil"
            uyari.informativeText = """
                LLM temizliği için Ollama gerekir (ücretsiz, yerel çalışır).
                İndirme sayfasını açayım mı? Kurduktan sonra bu menüden tekrar açabilirsin.

                Dikte, LLM olmadan da tam çalışır.
                """
            uyari.addButton(withTitle: "İndirme sayfasını aç")
            uyari.addButton(withTitle: "Vazgeç")
            if uyari.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(Ayarlar.ollamaIndirmeURL)
            }
            return
        }

        let uyari = NSAlert()
        uyari.messageText = "LLM modeli eksik"
        uyari.informativeText = """
            Ollama kurulu ama \(Ayarlar.ollamaModel) modeli yok.
            Şimdi indireyim mi? (~2,5 GB, bir kez — arka planda iner, bitince \
            LLM temizliği kendiliğinden açılır.)
            """
        uyari.addButton(withTitle: "İndir")
        uyari.addButton(withTitle: "Vazgeç")
        guard uyari.runModal() == .alertFirstButtonReturn else { return }

        durumYaz("LLM modeli indiriliyor…")
        await Ollama.kuruluysaBaslat()
        let oldu = await Ollama.modeliIndir { mesaj in
            Task { @MainActor in self.durumYaz(mesaj) }
        }
        if oldu, await Ollama.kullanilabilir() {
            llmKullan = true
            durumYaz("LLM modeli hazır — temizlik açıldı")
        } else {
            durumYaz("LLM modeli indirilemedi — internet var mı?")
        }
        await llmMenusunuTazele()
    }

    private func llmMenusunuTazele() async {
        let erisilebilir = await Ollama.kullanilabilir()
        if llmKullan && erisilebilir {
            llmOgesi.state = .on
            llmOgesi.title = "Ollama ile metin düzeltme — açık"
        } else if llmKullan {
            llmOgesi.state = .off
            llmOgesi.title = "Ollama ile metin düzeltme — Ollama erişilemez"
        } else {
            llmOgesi.state = .off
            llmOgesi.title = "Ollama ile metin düzeltme — kapalı"
        }
    }

    // MARK: İzinler

    @objc private func girisIzlemePaneliniAc() {
        izinPaneliniAc("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    @objc private func erisilebilirlikPaneliniAc() {
        izinPaneliniAc("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @objc private func mikrofonPaneliniAc() {
        izinPaneliniAc("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    private func izinPaneliniAc(_ adres: String) {
        if let url = URL(string: adres) { NSWorkspace.shared.open(url) }
    }

    private func izinMenusunuTazele() {
        girisIzlemeOgesi.state = girisIzlemeVar ? .on : .off
        erisilebilirlikOgesi.state = erisilebilirlikVar ? .on : .off
        mikrofonIzniOgesi.state =
            AVCaptureDevice.authorizationStatus(for: .audio) == .authorized ? .on : .off
    }

    /// Giriş İzleme veya Erişilebilirlik eksikken 2 saniyede bir durumu yeniden
    /// okur. Sistem Ayarları'ndan izin verilince uygulama yeniden başlatılmadan
    /// yakalanabilsin diye — Giriş İzleme özellikle, verildikten sonra tap'in
    /// kendiliğinden düzelmediği görülmüştü.
    private func izinBekcisiKur() {
        guard izinBekcisi == nil else { return }
        guard !girisIzlemeVar || !erisilebilirlikVar else { return }
        izinBekcisi = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.izinleriYokla() }
        }
    }

    private func izinleriYokla() {
        let yeniGirisIzleme = CGPreflightListenEventAccess()
        let yeniErisilebilirlik = AXIsProcessTrusted()
        var degisti = false

        if yeniGirisIzleme != girisIzlemeVar {
            Gunluk.yaz("giriş izleme izni değişti: \(girisIzlemeVar) -> \(yeniGirisIzleme)")
            let yenidenVerildi = !girisIzlemeVar && yeniGirisIzleme
            girisIzlemeVar = yeniGirisIzleme
            degisti = true
            if yenidenVerildi {
                tusDinleyici.dur()
                do {
                    try tusDinleyici.basla()
                    Gunluk.yaz("giriş izleme verildi — tuş dinleyicisi yeniden kuruldu")
                } catch {
                    Gunluk.yaz("tuş dinleyicisi yeniden kurulamadı: \(error.localizedDescription)")
                }
            }
        }

        if yeniErisilebilirlik != erisilebilirlikVar {
            Gunluk.yaz("erişilebilirlik izni değişti: \(erisilebilirlikVar) -> \(yeniErisilebilirlik)")
            erisilebilirlikVar = yeniErisilebilirlik
            degisti = true
        }

        if degisti {
            izinMenusunuTazele()
            bostaDurumunuTazele()
        }

        if girisIzlemeVar && erisilebilirlikVar {
            izinBekcisi?.invalidate()
            izinBekcisi = nil
        }
    }

    // MARK: Yardım / çıkış

    @objc private func nasilCalisirGoster() {
        let uyari = NSAlert()
        uyari.alertStyle = .informational
        uyari.messageText = "Listender nasıl çalışır"
        var metin = """
            Sağ ⌥ tuşuna basılı tutarken mikrofon kaydeder. Bırakınca ses, bu bilgisayardaki Whisper modeliyle yazıya çevrilir ve imlecin olduğu yere yapıştırılır. Ses ve metin bilgisayardan çıkmaz; internet yalnız modelin ilk indirilmesinde gerekir.

            Metin temizliği: "eee, ıı" gibi dolgular her zaman silinir; cümle başındaki "yani, hani, şey, işte" temizlenir; yarım saniyeden kısa basmalar yok sayılır.

            Ollama ile metin düzeltme (isteğe bağlı, varsayılan kapalı): bilgisayarda çalışan küçük bir dil modeli noktalamayı ve akıcılığı düzeltir. Ollama ayrı kurulur; kapalıyken dikte aynen çalışır. Anlamı değiştirebildiği için bilerek açılır.

            İzinler: Giriş İzleme (tuşu duymak), Erişilebilirlik (metni yazmak), Mikrofon (sesi almak). Üçü de İzinler menüsünden açılır.
            """
        if let surum = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            metin += "\n\nSürüm \(surum)"
        }
        uyari.informativeText = metin
        // Dock ikonu olmayan uygulamada (LSUIElement) pencere arkada kalıyor.
        NSApp.activate(ignoringOtherApps: true)
        uyari.runModal()
    }

    @objc private func cik() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: Durum gösterimi

    private func bostaIkonu() -> String {
        if !modelHazir { return Ikon.yukleniyor }
        if !mikrofonHazir { return Ikon.mikrofonYok }
        return Ikon.bosta
    }

    private func bostaDurumunuTazele() {
        guard !kayitta else { return }
        ikonYaz(bostaIkonu())
        if !girisIzlemeVar {
            durumYaz("Giriş İzleme izni yok — İzinler menüsünden aç")
        } else if !erisilebilirlikVar {
            durumYaz("Erişilebilirlik izni yok — metin panoda kalır")
        } else if !modelHazir {
            durumYaz("Model yükleniyor…")
        } else if !mikrofonHazir {
            durumYaz("Mikrofon yok — bağlanınca hazır olur")
        } else {
            durumYaz("Hazır — sağ ⌥ bas-konuş")
        }
    }

    private func bitir(_ mesaj: String) {
        durumYaz(mesaj)
        ikonYaz(bostaIkonu())
    }

    private func durumYaz(_ mesaj: String) { durumSatiri?.title = mesaj }
    private func ikonYaz(_ ikon: String) { durumOgesi?.button?.title = ikon }
}
