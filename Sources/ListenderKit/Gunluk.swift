import Foundation

/// Teşhis logu.
///
/// Python sürümü `/tmp/listender.log` kullanıyordu; dikte edilen metin oraya da
/// düşüyordu ve `/tmp` makinedeki herkese açık. 2026-07-23 denetimi bunu gizlilik
/// bulgusu olarak işaretlemişti. Log artık kullanıcının kendi klasöründe.
public enum Gunluk {
    private static let kuyruk = DispatchQueue(label: "listender.gunluk")
    private static let bicimlendirici: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    /// Metnin kendisi loglanmasın istenirse kapatılır (varsayılan: kapalı).
    /// Dikte içeriği hassas olabilir; ayıklama gerekince bilinçli açılır.
    public static var metinleriDeYaz = false

    public static func yaz(_ mesaj: String) {
        let satir = "\(bicimlendirici.string(from: Date())) \(mesaj)\n"
        FileHandle.standardError.write(Data(satir.utf8))
        kuyruk.async {
            let dosya = Ayarlar.logDosyasi
            try? FileManager.default.createDirectory(
                at: dosya.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let tutamac = try? FileHandle(forWritingTo: dosya) {
                defer { try? tutamac.close() }
                _ = try? tutamac.seekToEnd()
                try? tutamac.write(contentsOf: Data(satir.utf8))
            } else {
                try? Data(satir.utf8).write(to: dosya)
            }
        }
    }

    /// Dikte metni gibi hassas içeriği yalnız `metinleriDeYaz` açıkken yazar.
    public static func metin(_ etiket: String, _ icerik: String) {
        if metinleriDeYaz {
            yaz("\(etiket): \(icerik)")
        } else {
            yaz("\(etiket): (\(icerik.count) karakter)")
        }
    }
}
