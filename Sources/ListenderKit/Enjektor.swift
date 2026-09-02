import AppKit
import ApplicationServices

/// Metin enjeksiyonu — pano + Cmd-V simülasyonu.
///
/// Akış: mevcut panoyu sakla, metni panoya koy, Cmd-V gönder, kısa bekle, eski
/// panoyu geri yükle. Karakter karakter klavye simülasyonu macOS'ta Türkçe
/// karakterlerde güvenilmez olduğu için elendi; pano yolu kullanılır.
public enum Enjektor {

    private static let vTusKodu: CGKeyCode = 9   // ANSI 'v'

    public enum Sonuc: Equatable {
        case yazildi
        /// Erişilebilirlik izni yok: metin panoda bırakıldı, kullanıcı elle yapıştırabilir.
        case izinYokPanodaBirakildi
        case bosMetin
    }

    /// Erişilebilirlik izni var mı. İzin olmadan CGEvent gönderimi sessizce yutulur.
    public static func izinVarMi() -> Bool {
        AXIsProcessTrusted()
    }

    /// Metni aktif uygulamanın imlecine yaz.
    ///
    /// İzin yoksa **metin panoda bırakılır** ve eski pano geri yüklenmez —
    /// böylece dikte edilen metin kaybolmaz, kullanıcı Cmd-V ile kendisi yapıştırır.
    /// (2026-07-23 denetimi: izin yokken metin sessizce yok oluyordu.)
    @discardableResult
    public static func enjekteEt(_ metin: String) -> Sonuc {
        guard !metin.isEmpty else { return .bosMetin }

        let pano = NSPasteboard.general
        let eski = pano.string(forType: .string)

        pano.clearContents()
        pano.setString(metin, forType: .string)

        guard izinVarMi() else {
            Gunluk.yaz("erişilebilirlik izni yok — metin panoda bırakıldı")
            return .izinYokPanodaBirakildi
        }

        Thread.sleep(forTimeInterval: 0.02)   // pano yerleşsin
        yapistirTusuGonder()

        // Hedef uygulama yapıştırmayı bitirsin, sonra eski panoyu geri koy.
        Thread.sleep(forTimeInterval: Ayarlar.panoGeriYuklemeGecikmesi)
        pano.clearContents()
        if let eski { pano.setString(eski, forType: .string) }
        return .yazildi
    }

    private static func yapistirTusuGonder() {
        let kaynak = CGEventSource(stateID: .combinedSessionState)
        guard let bas = CGEvent(keyboardEventSource: kaynak, virtualKey: vTusKodu, keyDown: true),
              let birak = CGEvent(keyboardEventSource: kaynak, virtualKey: vTusKodu, keyDown: false)
        else { return }
        bas.flags = .maskCommand
        birak.flags = .maskCommand
        bas.post(tap: .cghidEventTap)
        birak.post(tap: .cghidEventTap)
    }
}
