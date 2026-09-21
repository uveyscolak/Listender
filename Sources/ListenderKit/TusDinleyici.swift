import AppKit
import CoreGraphics

/// Global değiştirici tuş dinleyicisi — CGEventTap.
///
/// Bas-konuş tetikleyicisi. Seçili tuş bir değiştirici (Control/Option/
/// Command/Shift, sol veya sağ) olduğu için normal tuş olayları değil
/// `.flagsChanged` olayları izlenir; hangi tuşun değiştiğini tuş kodundan
/// anlarız (bkz. `KayitTusu.tusKodu` — sol/sağ ayrımı cihaza özel bit
/// maskesiyle yapılır, `.maskAlternate` gibi genel maskeler iki tarafı
/// ayırmaz).
///
/// Bu tap **Giriş İzleme** ve **Erişilebilirlik** izni ister. İzin yoksa tap kurulamaz.
///
/// Tap kendi ayrı thread'inde, kendi `CFRunLoop`'unda çalışır — ana thread'e
/// (AppKit menü izleme, ses motoru yeniden yapılandırma, model işi) bağlı
/// değildir. Önceki sürümde tap ana thread'in run loop'una eklenmişti; ana
/// thread kısa süreliğine tıkandığında macOS tap'i "yanıt vermiyor" sayıp
/// kapatıyordu (`tapDisabledByTimeout`), kod bunu yakalayıp yeniden açıyordu
/// ama kapalı olduğu pencerede basılan tuş kayboluyordu.
public final class TusDinleyici {

    private let basildi: () -> Void
    private let birakildi: () -> Void

    /// İzin sorunu bildirimi: true = tap üst üste kapalı bulunuyor, izin eksik
    /// olabilir; false = düzeldi. Timer tap'in kendi thread'inde çalıştığı için
    /// çağrılar ana kuyruğa taşınır.
    public var izinSorunu: ((Bool) -> Void)?

    private var tap: CFMachPort?
    private var kaynak: CFRunLoopSource?
    private var basiliMi = false

    /// Seçili kayıt tuşu. Tap kendi thread'inde okur, `tusuDegistir(_:)` ana
    /// thread'den yazar — ikisi arasında `kilit` korur.
    private var tus: KayitTusu
    private let kilit = NSLock()

    private var thread: Thread?
    private var thredRunLoop: CFRunLoop?
    private var guvenlikAgiZamanlayici: CFRunLoopTimer?
    private var ustUsteKapali = 0

    public init(tus: KayitTusu, basildi: @escaping () -> Void, birakildi: @escaping () -> Void) {
        self.tus = tus
        self.basildi = basildi
        self.birakildi = birakildi
    }

    deinit { dur() }

    public var calisiyorMu: Bool { tap != nil }

    /// Dinlemeyi başlat. Giriş İzleme izni yoksa `Hata.tapKurulamadi` fırlatır.
    public func basla() throws {
        guard tap == nil else { return }

        let geriCagri: CGEventTapCallBack = { _, tur, olay, kullanici in
            guard let kullanici else { return Unmanaged.passUnretained(olay) }
            let dinleyici = Unmanaged<TusDinleyici>.fromOpaque(kullanici).takeUnretainedValue()
            dinleyici.olayGeldi(tur: tur, olay: olay)
            return Unmanaged.passUnretained(olay)
        }

        let kendisi = Unmanaged.passUnretained(self).toOpaque()
        guard let yeniTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,          // olayları yutma, sadece dinle
            eventsOfInterest: CGEventMask(1 << CGEventType.flagsChanged.rawValue),
            callback: geriCagri,
            userInfo: kendisi)
        else {
            throw Hata.tapKurulamadi
        }

        tap = yeniTap
        kaynak = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, yeniTap, 0)

        let hazir = DispatchSemaphore(value: 0)
        let yeniThread = Thread { [weak self] in
            guard let self, let kaynak = self.kaynak, let tap = self.tap else {
                hazir.signal()
                return
            }
            let dongu = CFRunLoopGetCurrent()
            self.thredRunLoop = dongu
            CFRunLoopAddSource(dongu, kaynak, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)

            // Güvenlik ağı: bildirim kaçarsa tap sessizce kapalı kalmasın diye
            // aynı thread'de periyodik kontrol. Ana thread'de olsaydı ana thread
            // tıkandığında bu da tıkanırdı, o yüzden tap'in kendi thread'inde.
            let zamanlayici = CFRunLoopTimerCreateWithHandler(
                kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + 2, 2, 0, 0
            ) { [weak self] _ in
                guard let self, let tap = self.tap else { return }
                if !CGEvent.tapIsEnabled(tap: tap) {
                    CGEvent.tapEnable(tap: tap, enable: true)
                    self.ustUsteKapali += 1
                    if self.ustUsteKapali == 1 {
                        Gunluk.yaz("tap kapalı bulundu, yeniden açıldı (periyodik kontrol)")
                    } else if self.ustUsteKapali == 3 {
                        Gunluk.yaz("tap üst üste 3 kez kapalı bulundu — Giriş İzleme izni verilmemiş olabilir")
                        DispatchQueue.main.async { self.izinSorunu?(true) }
                    }
                    // 3'ten büyükse hiç log yazma: izin gerçekten yoksa sonsuza
                    // dek her 2 saniyede gürültü olurdu.
                } else if self.ustUsteKapali >= 3 {
                    Gunluk.yaz("tap yeniden sağlıklı")
                    DispatchQueue.main.async { self.izinSorunu?(false) }
                    self.ustUsteKapali = 0
                } else {
                    self.ustUsteKapali = 0
                }
            }
            self.guvenlikAgiZamanlayici = zamanlayici
            if let zamanlayici {
                CFRunLoopAddTimer(dongu, zamanlayici, .commonModes)
            }

            hazir.signal()
            CFRunLoopRun()   // bu thread'i sonsuza dek burada tut
        }
        yeniThread.name = "listender.tus-dinleyici"
        yeniThread.start()
        hazir.wait()
        thread = yeniThread

        Gunluk.yaz("tuş dinleyicisi kuruldu (\(guncelTus().ad), ayrı thread)")
    }

    /// Tap'i yeniden kurmadan kayıt tuşunu değiştirir. Tuş değişince yarım
    /// kalmış bir basış ("eski tuş basılıyken değiştirildi") kayıt açık
    /// bırakmasın diye `basiliMi` sıfırlanır.
    public func tusuDegistir(_ yeni: KayitTusu) {
        kilit.lock()
        tus = yeni
        kilit.unlock()
        basiliMi = false
        Gunluk.yaz("kayıt tuşu değişti: \(yeni.ad)")
    }

    private func guncelTus() -> KayitTusu {
        kilit.lock()
        defer { kilit.unlock() }
        return tus
    }

    public func dur() {
        ustUsteKapali = 0
        // Tuş basılıyken durdurulup yeniden kurulabiliyor (izin sonradan
        // verilince). Bayrak açık kalırsa yeni tap'te ilk basış yutulur.
        basiliMi = false
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let dongu = thredRunLoop {
            if let kaynak { CFRunLoopRemoveSource(dongu, kaynak, .commonModes) }
            if let guvenlikAgiZamanlayici { CFRunLoopRemoveTimer(dongu, guvenlikAgiZamanlayici, .commonModes) }
            CFRunLoopStop(dongu)
        }
        if let guvenlikAgiZamanlayici { CFRunLoopTimerInvalidate(guvenlikAgiZamanlayici) }
        guvenlikAgiZamanlayici = nil
        kaynak = nil
        tap = nil
        thredRunLoop = nil
        thread = nil
    }

    private func olayGeldi(tur: CGEventType, olay: CGEvent) {
        // Sistem tap'i zaman aşımı veya kullanıcı girdisiyle kapatabilir; geri aç.
        if tur == .tapDisabledByTimeout || tur == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            Gunluk.yaz("tuş dinleyicisi sistem tarafından kapatılmıştı, yeniden açıldı")
            return
        }
        let seciliTus = guncelTus()
        guard tur == .flagsChanged,
              olay.getIntegerValueField(.keyboardEventKeycode) == seciliTus.tusKodu
        else { return }

        // Bayrak duruyorsa basıldı, kalktıysa bırakıldı.
        let simdiBasili = (olay.flags.rawValue & seciliTus.bayrakBiti) != 0
        guard simdiBasili != basiliMi else { return }
        basiliMi = simdiBasili

        // Geri çağrılar UI'a dokunuyor: ana kuyruğa taşı.
        let is_ = simdiBasili ? basildi : birakildi
        DispatchQueue.main.async(execute: is_)
    }

    public enum Hata: LocalizedError {
        case tapKurulamadi
        public var errorDescription: String? {
            switch self {
            case .tapKurulamadi:
                return "Klavye dinlenemiyor — Giriş İzleme izni gerekiyor."
            }
        }
    }
}
