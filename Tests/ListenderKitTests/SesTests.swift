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
