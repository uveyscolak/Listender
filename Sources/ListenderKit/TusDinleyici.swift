import AppKit
import CoreGraphics

/// Global sağ Option (⌥) dinleyicisi — CGEventTap.
///
/// Bas-konuş tetikleyicisi. Sağ ⌥ değiştirici tuş olduğu için normal tuş
/// olayları değil `.flagsChanged` olayları izlenir; hangi tuşun değiştiğini
/// tuş kodundan anlarız (sağ ⌥ = 61, sol ⌥ = 58 — sol tuşa tepki verilmez).
///
/// Bu tap **Giriş İzleme** izni ister. İzin yoksa tap kurulamaz.
public final class TusDinleyici {

    /// Sağ Option'ın sanal tuş kodu (kVK_RightOption).
    private static let sagOptionKodu: Int64 = 61

    private let basildi: () -> Void
    private let birakildi: () -> Void

    private var tap: CFMachPort?
    private var kaynak: CFRunLoopSource?
    private var basiliMi = false

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
        CFRunLoopAddSource(CFRunLoopGetMain(), kaynak, .commonModes)
        CGEvent.tapEnable(tap: yeniTap, enable: true)
        Gunluk.yaz("tuş dinleyicisi kuruldu (sağ ⌥)")
    }

    public func dur() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let kaynak { CFRunLoopRemoveSource(CFRunLoopGetMain(), kaynak, .commonModes) }
        kaynak = nil
        tap = nil
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
