import Foundation
import Testing

@testable import ListenderKit

@Suite("RMS ölçümü")
struct RMSTests {

    @Test("Sessizlikte sıfır")
    func sessizlik() {
        #expect(rmsHesapla([Float](repeating: 0, count: 1000)) == 0)
    }

    @Test("Boş dizide sıfır (sıfıra bölme yok)")
    func bosDizi() {
        #expect(rmsHesapla([]) == 0)
    }

    @Test("Sabit genlikte genliğin kendisi")
    func sabitGenlik() {
        let rms = rmsHesapla([Float](repeating: 0.5, count: 100))
        #expect(abs(rms - 0.5) < 0.0001)
    }

    @Test("Sessizlik eşiği gerçek konuşmayı elemiyor")
    func esikAyarli() {
        // Canlı ölçüm: kablosuz mikrofonda konuşma RMS ~0,009 çıkıyordu.
        // Eşik bunun çok altında olmalı ki gerçek konuşma elenmesin.
        #expect(Ayarlar.sessizlikRMS < 0.009)
    }
}

@Suite("Tepe normalizasyonu")
struct NormalizasyonTests {

    private let cozumleyici = Cozumleyici()

    @Test("Cılız ses hedef tepeye çekilir")
    func cilizSesYukselir() {
        // Kablosuz mikrofon çok kısık gelebiliyor; whisper'ın rahat çözdüğü
        // seviyeye çekilmesi gerekiyor.
        let cikti = cozumleyici.tepeNormalize([0.01, -0.005, 0.002])
        let tepe = cikti.map(abs).max() ?? 0
        #expect(abs(tepe - Ayarlar.normalizeTepe) < 0.0001)
    }

    @Test("Şekil korunur — sadece ölçeklenir")
    func sekilKorunur() {
        let girdi: [Float] = [0.1, -0.05, 0.025]
        let cikti = cozumleyici.tepeNormalize(girdi)
        // Oranlar aynı kalmalı: ikinci örnek birincinin yarısı, işareti ters.
        #expect(abs(cikti[1] / cikti[0] - girdi[1] / girdi[0]) < 0.0001)
        #expect(cikti[1] < 0)
    }

    @Test("Tamamen sessiz dizi olduğu gibi döner (sıfıra bölme yok)")
    func sessizBozulmaz() {
        let sessiz = [Float](repeating: 0, count: 10)
        #expect(cozumleyici.tepeNormalize(sessiz) == sessiz)
    }

    @Test("Boş dizi çökmez")
    func bosCokmez() {
        #expect(cozumleyici.tepeNormalize([]).isEmpty)
    }
}

@Suite("Ayarlar tutarlılığı")
struct AyarTests {

    @Test("Örnekleme whisper'ın beklediği 16 kHz")
    func ornekleme() {
        #expect(Ayarlar.ornekleme == 16_000)
    }

    @Test("Pre-roll en kısa kayıttan kısa — yoksa her basma pre-roll'la dolar")
    func preRollTutarli() {
        #expect(Ayarlar.preRollSaniye <= Ayarlar.enKisaKayitSaniye)
    }

    @Test("LLM varsayılan kapalı")
    func llmKapali() {
        // qwen3:4b-instruct hâlâ kişi kayması yapabiliyor ("verdim" -> "verildi"),
        // o yüzden bilinçli olarak kapalı geliyor (bkz. brain/Kararlar 2026-07-03).
        #expect(Ayarlar.llmVarsayilanAcik == false)
    }
}

@Suite("Boş kayıt teşhis dosyası")
struct BosKayitTests {

    /// Gerçek wav yazıp geri okuyan tam tur. Teşhis yolu ancak bu tur
    /// çalışıyorsa işe yarar: boş dönen kayıt yeniden denenebilmeli.
    @Test("Yazılan wav geri okununca aynı ses çıkar")
    func yazOkuTuru() throws {
        let klasor = FileManager.default.temporaryDirectory
            .appendingPathComponent("listender-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: klasor) }

        // 0,25 sn 440 Hz sinüs — sessizlikten ayırt edilebilir gerçek sinyal.
        let sayi = Int(Ayarlar.ornekleme * 0.25)
        let girdi = (0..<sayi).map {
            Float(sin(2 * Double.pi * 440 * Double($0) / Ayarlar.ornekleme)) * 0.5
        }

        let hedef = klasor.appendingPathComponent("deneme.wav")
        try SesDosyasi.wavYaz(girdi, hedef)
        #expect(FileManager.default.fileExists(atPath: hedef.path))

        let cikti = try SesDosyasi.oku16kHz(hedef.path)
        #expect(cikti.count == girdi.count)
        // 16 bit tamsayıya yuvarlanıyor; RMS korunmalı.
        #expect(abs(rmsHesapla(cikti) - rmsHesapla(girdi)) < 0.01)
    }

    @Test("Boş dizi yazılmaz")
    func bosDiziYazilmaz() {
        #expect(SesDosyasi.bosKaydiSakla([]) == nil)
    }

    @Test("Klasör sınırı aşılınca en eskisi silinir")
    func eskilerSilinir() throws {
        let klasor = SesDosyasi.bosKayitKlasoru
        let yonetici = FileManager.default

        // Testin kendi dosyaları dışındakilere dokunmamak için önce mevcut
        // durumu say; test sonunda yalnız kendi yazdıklarını siler.
        let oncekiDosyalar: [URL] = (try? yonetici.contentsOfDirectory(
            at: klasor, includingPropertiesForKeys: [])) ?? []
        let oncekiler = Set(oncekiDosyalar.map { $0.lastPathComponent })

        let ses = [Float](repeating: 0.1, count: 1600)
        var yazilanlar: [URL] = []
        defer { for yol in yazilanlar { try? yonetici.removeItem(at: yol) } }

        // Sınırı 3'e çekip 5 dosya yaz: en eski 2'si silinmeli.
        for i in 0..<5 {
            let zaman = Date().addingTimeInterval(Double(i))
            if let yol = SesDosyasi.bosKaydiSakla(ses, zaman: zaman, enFazla: 3) {
                yazilanlar.append(yol)
            }
        }

        let sonrakiDosyalar: [URL] = (try? yonetici.contentsOfDirectory(
            at: klasor, includingPropertiesForKeys: [])) ?? []
        let sonrakiler: [String] = sonrakiDosyalar
            .filter { $0.pathExtension.lowercased() == "wav" }
            .map { $0.lastPathComponent }
        let yeniler = sonrakiler.filter { !oncekiler.contains($0) }

        #expect(yeniler.count <= 3)
        // En son yazılan mutlaka duruyor olmalı.
        if let sonuncu = yazilanlar.last {
            #expect(yonetici.fileExists(atPath: sonuncu.path))
        }
    }
}

@Suite("Uyarı ikonu ayarı")
struct UyariTests {

    @Test("Göze çarpacak kadar uzun, yolu tıkamayacak kadar kısa")
    func makulSure() {
        #expect(Ayarlar.uyariIkonuSaniye >= 2)
        #expect(Ayarlar.uyariIkonuSaniye <= 5)
    }
}
