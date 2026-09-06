import AppKit
import CoreGraphics

/// Global sağ Option (⌥) dinleyicisi — CGEventTap.
///
/// Bas-konuş tetikleyicisi. Sağ ⌥ değiştirici tuş olduğu için normal tuş
/// olayları değil `.flagsChanged` olayları izlenir; hangi tuşun değiştiğini
/// tuş kodundan anlarız (sağ ⌥ = 61, sol ⌥ = 58 — sol tuşa tepki verilmez).
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

    /// Sağ Option'ın sanal tuş kodu (kVK_RightOption).
    private static let sagOptionKodu: Int64 = 61

    private let basildi: () -> Void
    private let birakildi: () -> Void

    private var tap: CFMachPort?
    private var kaynak: CFRunLoopSource?
    private var basiliMi = false

    private var thread: Thread?
    private var thredRunLoop: CFRunLoop?

    public init(basildi: @escaping () -> Void, birakildi: @escaping () -> Void) {
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
            hazir.signal()
            CFRunLoopRun()   // bu thread'i sonsuza dek burada tut
        }
        yeniThread.name = "listender.tus-dinleyici"
        yeniThread.start()
        hazir.wait()
        thread = yeniThread

        Gunluk.yaz("tuş dinleyicisi kuruldu (sağ ⌥, ayrı thread)")
    }

    public func dur() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let dongu = thredRunLoop {
            if let kaynak { CFRunLoopRemoveSource(dongu, kaynak, .commonModes) }
            CFRunLoopStop(dongu)
        }
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
        guard tur == .flagsChanged,
              olay.getIntegerValueField(.keyboardEventKeycode) == Self.sagOptionKodu
        else { return }

        // Bayrak duruyorsa basıldı, kalktıysa bırakıldı.
        let simdiBasili = olay.flags.contains(.maskAlternate)
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
