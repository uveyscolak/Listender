import AppKit

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
    private var llmOgesi: NSMenuItem!
    private var mikrofonSayaci: Timer?

    private var modelHazir = false
    private var mikrofonHazir = false
    private var kayitta = false
    private var kayitBasladi = Date()
    private var llmKullan = Ayarlar.llmVarsayilanAcik

    private var tusDinleyici: TusDinleyici!

    public override init() {
        super.init()
    }

    // MARK: Açılış

    public func applicationDidFinishLaunching(_ notification: Notification) {
        menuyuKur()

        cozumleyici = Cozumleyici { [weak self] mesaj in
            Task { @MainActor in self?.durumYaz(mesaj) }
        }

        tusDinleyici = TusDinleyici(
            basildi: { [weak self] in self?.kaydiBaslat() },
            birakildi: { [weak self] in self?.kaydiBitir() })

        do {
            try tusDinleyici.basla()
        } catch {
            durumYaz("Giriş İzleme izni gerekiyor")
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
        menu.addItem(.separator())

        llmOgesi = NSMenuItem(
            title: "LLM temizliği (Ollama)",
            action: #selector(llmDegistir), keyEquivalent: "")
        llmOgesi.target = self
        menu.addItem(llmOgesi)
        menu.addItem(.separator())

        let izinler = NSMenuItem(
            title: "İzinleri aç…", action: #selector(izinleriAc), keyEquivalent: "")
        izinler.target = self
        menu.addItem(izinler)

        let cikis = NSMenuItem(title: "Çıkış", action: #selector(cik), keyEquivalent: "q")
        cikis.target = self
        menu.addItem(cikis)

        durumOgesi.menu = menu
    }

    // MARK: Model

    private func modeliYukle() async {
        do {
            try await cozumleyici.yukle()
            modelHazir = true
            bostaDurumunuTazele()
        } catch {
            Gunluk.yaz("model yüklenemedi: \(error.localizedDescription)")
            durumYaz("Model hatası: \(error.localizedDescription)")
            ikonYaz(Ikon.hata)
        }
    }

    private var hazirMi: Bool { modelHazir && mikrofonHazir }

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
            bitir("Ses yok — mikrofon açık mı?")
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
            llmOgesi.title = "LLM temizliği (Ollama) — açık"
        } else if llmKullan {
            llmOgesi.state = .off
            llmOgesi.title = "LLM temizliği — Ollama erişilemez"
        } else {
            llmOgesi.state = .off
            llmOgesi.title = "LLM temizliği (Ollama) — kapalı"
        }
    }

    // MARK: İzinler / çıkış

    @objc private func izinleriAc() {
        for ayar in [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ] {
            if let url = URL(string: ayar) { NSWorkspace.shared.open(url) }
        }
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
        if !modelHazir {
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
