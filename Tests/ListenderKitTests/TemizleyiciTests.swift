import Testing

@testable import ListenderKit

@Suite("Sert dolgular")
struct SertDolguTests {

    @Test("Nerede geçerse geçsin silinir")
    func herYerdeSilinir() {
        #expect(Temizleyici.regexTemizle("eee bugün toplantı var") == "bugün toplantı var")
        #expect(Temizleyici.regexTemizle("bugün eee toplantı var") == "bugün toplantı var")
        #expect(Temizleyici.regexTemizle("bugün toplantı var eee") == "bugün toplantı var")
    }

    @Test("Kelime içinde geçen harf dizisi silinmez")
    func kelimeIcindeDokunulmaz() {
        // "hı" bir dolgu ama "hıçkırık" içindeki "hı" kelime değil.
        #expect(Temizleyici.regexTemizle("hıçkırık tuttu") == "hıçkırık tuttu")
        #expect(Temizleyici.regexTemizle("teenager") == "teenager")
    }
}

@Suite("Yumuşak dolgular")
struct YumusakDolguTests {

    // Tasarım kararı (Python sürümünden birebir): "yani/hani/şey/işte/falan"
    // cümlenin ortasında gerçek anlam taşıyabilir, o yüzden yalnız cümle başında
    // ve ardışık tekrarda temizlenir.

    @Test("Cümle başında silinir")
    func cumleBasindaSilinir() {
        #expect(Temizleyici.regexTemizle("yani bugün toplantı var") == "bugün toplantı var")
        #expect(Temizleyici.regexTemizle("bugün var. hani yarın da var")
                == "bugün var. yarın da var")
    }

    @Test("Cümle ortasında korunur")
    func cumleOrtasindaKorunur() {
        #expect(Temizleyici.regexTemizle("bugün yani toplantı var") == "bugün yani toplantı var")
        #expect(Temizleyici.regexTemizle("bir şey söyledi") == "bir şey söyledi")
    }

    @Test("Ardışık tekrar teke iner")
    func ardisikTekrar() {
        #expect(Temizleyici.regexTemizle("bugün yani yani toplantı") == "bugün yani toplantı")
        #expect(Temizleyici.regexTemizle("bugün şey şey şey toplantı") == "bugün şey toplantı")
    }
}

@Suite("Boşluk ve noktalama")
struct BicimTests {

    @Test("Çoklu boşluk tekleşir")
    func cokluBosluk() {
        #expect(Temizleyici.regexTemizle("bugün    toplantı") == "bugün toplantı")
    }

    @Test("Noktalama öncesi boşluk atılır")
    func noktalamaOncesi() {
        #expect(Temizleyici.regexTemizle("bugün toplantı , var .") == "bugün toplantı, var.")
    }

    @Test("Çift virgül tekleşir")
    func ciftVirgul() {
        #expect(Temizleyici.regexTemizle("bugün ,, toplantı") == "bugün, toplantı")
    }

    @Test("Baştaki boşluk ve virgül atılır")
    func bastakiler() {
        #expect(Temizleyici.regexTemizle("  , bugün toplantı") == "bugün toplantı")
    }
}

@Suite("Halüsinasyon filtresi")
struct HalusinasyonTests {

    // Whisper sessiz/boş seste bu kalıpları uyduruyor (altyazı jenerikleri).
    @Test("Metnin tamamı halüsinasyonsa komple atılır")
    func tamamiHalusinasyon() {
        #expect(Temizleyici.regexTemizle("Altyazı M.K.") == "")
        #expect(Temizleyici.regexTemizle("abone ol") == "")
        #expect(Temizleyici.regexTemizle("İzlediğiniz için teşekkür") == "")
    }

    @Test("Cümlenin parçasıysa dokunulmaz")
    func parcaysaDokunulmaz() {
        let metin = "izlediğiniz için teşekkür ederim ama şimdi gitmem lazım"
        #expect(Temizleyici.regexTemizle(metin) == metin)
    }
}

@Suite("Halüsinasyon filtresi — ses bağlamı")
struct HalusinasyonBaglamTests {

    // Kural: "teşekkür ederim" gerçekten söylenebilecek bir cümle. Tam metin
    // eşleşmesiyle silmek yalnız ses cılızken veya kayıt çok kısayken doğru;
    // konuşma seviyesinde bir kayıtta kullanıcı onu gerçekten demiştir.
    // Logdaki dört vakanın RMS'i 0,0004-0,0022, süreleri 2,1-2,9 sn
    // (2026-09-13 analizi, 363 kayıt); başarılı diktenin RMS medyanı 0,0108.

    private let konusma = Temizleyici.SesBaglami(rms: 0.0108, sureSaniye: 3.0)
    private let cilizSes = Temizleyici.SesBaglami(rms: 0.0005, sureSaniye: 2.5)
    private let kisaKayit = Temizleyici.SesBaglami(rms: 0.02, sureSaniye: 0.7)

    @Test("Cılız seste tam eşleşme silinir")
    func cilizSesteSilinir() {
        #expect(Temizleyici.regexTemizle("teşekkür ederim", ses: cilizSes) == "")
        #expect(Temizleyici.regexTemizle("Altyazı M.K.", ses: cilizSes) == "")
    }

    @Test("Konuşma seviyesinde tam eşleşme KORUNUR")
    func konusmadaKorunur() {
        // Asıl düzeltme bu: kullanıcı gerçekten "teşekkür ederim" demiş olabilir.
        #expect(Temizleyici.regexTemizle("teşekkür ederim", ses: konusma) == "teşekkür ederim")
        #expect(Temizleyici.regexTemizle("Abone ol", ses: konusma) == "Abone ol")
    }

    @Test("Çok kısa kayıtta ses yüksek olsa da silinir")
    func kisaKayittaSilinir() {
        // Yarım saniyelik basmada anlamlı bir cümle söylenmiş olamaz.
        #expect(Temizleyici.regexTemizle("teşekkür ederim", ses: kisaKayit) == "")
    }

    @Test("Bağlam verilmezse eski davranış sürer")
    func baglamsizEskiDavranis() {
        #expect(Temizleyici.regexTemizle("teşekkür ederim") == "")
    }

    @Test("Konuşma seviyesinde dolgu temizliği yine çalışır")
    func konusmadaDolguTemizlenir() {
        // Bağlam yalnız tam metin eşleşmesini etkiler, geri kalan hat aynı.
        #expect(Temizleyici.regexTemizle("eee bugün toplantı var", ses: konusma)
                == "bugün toplantı var")
    }

    @Test("Eşik sessizlik eşiğinden türetilmiş, uydurulmamış")
    func esikTuretilmis() {
        #expect(Ayarlar.halusinasyonUstRMS == Ayarlar.sessizlikRMS * 25)
        // Logdaki dört vakanın en yükseği 0,0022 — hepsi bandın içinde kalmalı.
        #expect(Ayarlar.halusinasyonUstRMS > 0.0022)
        // Başarılı diktenin 10. yüzdeliği 0,0054 — gerçek konuşma bandın
        // üstünde kalmalı, yoksa söylenen cümle silinir.
        #expect(Ayarlar.halusinasyonUstRMS < 0.0054)
    }
}

@Suite("Boş girdi")
struct BosGirdiTests {

    @Test("Boş ve yalnız boşluktan ibaret girdi boş döner")
    func bosDoner() {
        #expect(Temizleyici.regexTemizle("") == "")
        #expect(Temizleyici.regexTemizle("   \n  ") == "")
    }
}

@Suite("Ollama yardımcıları")
struct OllamaTests {

    @Test("qwen3 düşünme blokları atılır")
    func dusunmeAyiklanir() {
        #expect(Ollama.dusunmeyiAyikla("<think>uzun uzun düşünüyorum</think>Bugün toplantı var.")
                == "Bugün toplantı var.")
        #expect(Ollama.dusunmeyiAyikla("<think>a\nb\nc</think>  Sonuç.") == "Sonuç.")
    }

    @Test("Düşünme bloğu yoksa metin aynen kalır")
    func blokYoksaAyni() {
        #expect(Ollama.dusunmeyiAyikla("Bugün toplantı var.") == "Bugün toplantı var.")
    }
}
