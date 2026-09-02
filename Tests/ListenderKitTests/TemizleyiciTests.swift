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
