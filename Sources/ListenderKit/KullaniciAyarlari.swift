import Foundation

/// Kullanıcının değiştirebildiği, `UserDefaults` üstünde kalıcı ayarlar.
/// `Ayarlar.swift`'teki sabitlerden farkı: buradakiler menüden değiştirilir
/// ve uygulama kapanıp açılınca korunur.
public enum KullaniciAyarlari {
    static let kayitTusuAnahtari = "kayitTusu"

    /// Test edilebilirlik için enjekte edilebilir depo; varsayılan `.standard`.
    public static var depo: UserDefaults = .standard

    /// Seçili kayıt tuşu. Okurken değer yoksa veya bozuksa `KayitTusu.varsayilan`
    /// döner; yazarken rawValue string olarak saklanır.
    public static var kayitTusu: KayitTusu {
        get {
            guard let ham = depo.string(forKey: kayitTusuAnahtari),
                  let tus = KayitTusu(rawValue: ham)
            else { return .varsayilan }
            return tus
        }
        set {
            depo.set(newValue.rawValue, forKey: kayitTusuAnahtari)
        }
    }
}
