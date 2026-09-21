import Foundation
import Testing

@testable import ListenderKit

@Suite("KayitTusu")
struct KayitTusuTests {

    // Her satır: case, beklenen tusKodu, beklenen bayrakBiti.
    private let tablo: [(tus: KayitTusu, tusKodu: Int64, bayrakBiti: UInt64)] = [
        (.solControl, 59, 0x1),
        (.sagControl, 62, 0x2000),
        (.solOption, 58, 0x20),
        (.sagOption, 61, 0x40),
        (.solCommand, 55, 0x8),
        (.sagCommand, 54, 0x10),
        (.solShift, 56, 0x2),
        (.sagShift, 60, 0x4),
    ]

    @Test("Her case için tuş kodu ve bayrak biti beklenen değerle eşleşiyor")
    func kodlarVeBayraklar() {
        for satir in tablo {
            #expect(satir.tus.tusKodu == satir.tusKodu)
            #expect(satir.tus.bayrakBiti == satir.bayrakBiti)
        }
    }

    @Test("rawValue gidiş dönüşü aynı case'i veriyor")
    func rawValueGidisDonus() {
        for tus in KayitTusu.allCases {
            #expect(KayitTusu(rawValue: tus.rawValue) == tus)
        }
    }

    @Test("Varsayılan sağ Option")
    func varsayilan() {
        #expect(KayitTusu.varsayilan == .sagOption)
    }

    @Test("Sekiz case de benzersiz tuş kodu ve bayrak biti taşıyor")
    func benzersizlik() {
        let kodlar = Set(KayitTusu.allCases.map(\.tusKodu))
        let bitler = Set(KayitTusu.allCases.map(\.bayrakBiti))
        #expect(kodlar.count == KayitTusu.allCases.count)
        #expect(bitler.count == KayitTusu.allCases.count)
    }
}

// `.serialized`: `KullaniciAyarlari.depo` statik/paylaşımlı bir alan, testler
// paralel koşarsa biri diğerinin deposunu değiştirip çapraz kirlenmeye yol
// açar (bu haliyle bir kez ölçüldü: "Yazılan tuş" testi solCommand yazdıktan
// hemen sonra "Bozuk string" testi kendi bozuk değerini değil onun okuduğu
// depoyu görüyordu).
@Suite("KullaniciAyarlari", .serialized)
final class KullaniciAyarlariTests {

    private let depo = UserDefaults(suiteName: "listender.test.\(UUID().uuidString)")!
    private let eskiDepo: UserDefaults

    init() {
        eskiDepo = KullaniciAyarlari.depo
        KullaniciAyarlari.depo = depo
    }

    deinit {
        KullaniciAyarlari.depo = eskiDepo
    }

    @Test("Hiç yazılmamışsa varsayılan döner")
    func hicYazilmamis() {
        #expect(KullaniciAyarlari.kayitTusu == .varsayilan)
    }

    @Test("Yazılan tuş geri okunuyor")
    func yazVeOku() {
        KullaniciAyarlari.kayitTusu = .solCommand
        #expect(KullaniciAyarlari.kayitTusu == .solCommand)
    }

    @Test("Bozuk string yazılınca varsayılana düşer")
    func bozukDeger() {
        depo.set("olmayan-tus-degeri", forKey: KullaniciAyarlari.kayitTusuAnahtari)
        #expect(KullaniciAyarlari.kayitTusu == .varsayilan)
    }
}
