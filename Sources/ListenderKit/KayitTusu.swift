import Foundation

/// Bas-konuş kaydını tetikleyen değiştirici (modifier) tuş.
///
/// Yalnız değiştirici tuşlar seçilebiliyor: `TusDinleyici` `.flagsChanged`
/// olaylarını dinliyor, normal tuş basışları (`.keyDown`/`.keyUp`) bu tap'e
/// hiç gelmiyor. fn tuşu listede yok: macOS onu kendi dikte/emoji kısayolu
/// için kullanıyor, oraya el uzatmak sistemle çakışır.
///
/// `CaseIterable` sırası menüde göründüğü sıradır: önce sol/sağ Control,
/// sonra Option, Command, Shift.
public enum KayitTusu: String, CaseIterable, Sendable {
    case solControl
    case sagControl
    case solOption
    case sagOption
    case solCommand
    case sagCommand
    case solShift
    case sagShift

    /// Sanal tuş kodu (kVK_*). `.flagsChanged` olayında `.keyboardEventKeycode`
    /// alanıyla kıyaslanır.
    public var tusKodu: Int64 {
        switch self {
        case .solControl: return 59
        case .sagControl: return 62
        case .solOption: return 58
        case .sagOption: return 61
        case .solCommand: return 55
        case .sagCommand: return 54
        case .solShift: return 56
        case .sagShift: return 60
        }
    }

    /// IOLLEvent.h'daki cihaza özel değiştirici tuş bit maskesi. `.maskAlternate`
    /// gibi genel maskeler sol/sağ tuşu ayırmıyor, bu bit ayırıyor.
    public var bayrakBiti: UInt64 {
        switch self {
        case .solControl: return 0x1      // NX_DEVICELCTLKEYMASK
        case .sagControl: return 0x2000   // NX_DEVICERCTLKEYMASK
        case .solOption: return 0x20      // NX_DEVICELALTKEYMASK
        case .sagOption: return 0x40      // NX_DEVICERALTKEYMASK
        case .solCommand: return 0x8      // NX_DEVICELCMDKEYMASK
        case .sagCommand: return 0x10     // NX_DEVICERCMDKEYMASK
        case .solShift: return 0x2        // NX_DEVICELSHIFTKEYMASK
        case .sagShift: return 0x4        // NX_DEVICERSHIFTKEYMASK
        }
    }

    /// Menüde ve kullanıcıya görünen metinlerde kullanılan ad.
    public var ad: String {
        switch self {
        case .solControl: return "Sol Control (⌃)"
        case .sagControl: return "Sağ Control (⌃)"
        case .solOption: return "Sol Option (⌥)"
        case .sagOption: return "Sağ Option (⌥)"
        case .solCommand: return "Sol Command (⌘)"
        case .sagCommand: return "Sağ Command (⌘)"
        case .solShift: return "Sol Shift (⇧)"
        case .sagShift: return "Sağ Shift (⇧)"
        }
    }

    public static let varsayilan: KayitTusu = .sagOption
}
