import AppKit
import ListenderKit

// Alt komut: metin temizlik hattının uçtan uca kanıtı (mikrofon/model gerektirmez).
// Kurulum script'i bunu çalıştırıp çıkış koduna bakar.
if CommandLine.arguments.dropFirst().first == "listender-temizlik-smoke" {
    // Her satır: girdi, beklenen çıktı, ne sınanıyor.
    let durumlar: [(String, String, String)] = [
        ("eee bugün toplantı var", "bugün toplantı var",
         "sert dolgu her yerde silinir"),
        ("yani bugün toplantı var. hani yarın da var", "bugün toplantı var. yarın da var",
         "yumuşak dolgu cümle başında silinir"),
        ("bugün yani toplantı var", "bugün yani toplantı var",
         "yumuşak dolgu cümle ortasında KORUNUR"),
        ("bugün yani yani toplantı var", "bugün yani toplantı var",
         "ardışık tekrar teke iner"),
        ("bugün  toplantı ,, var .", "bugün toplantı, var.",
         "boşluk ve noktalama düzelir"),
        ("Altyazı M.K.", "", "halüsinasyon kalıbı komple atılır"),
    ]

    var hataVar = false
    for (girdi, beklenen, aciklama) in durumlar {
        let cikti = Temizleyici.regexTemizle(girdi)
        if cikti != beklenen {
            FileHandle.standardError.write(Data(
                "SMOKE FAIL (\(aciklama))\n  girdi:    \(girdi)\n  beklenen: \(beklenen)\n  çıktı:    \(cikti)\n".utf8))
            hataVar = true
        }
    }
    if hataVar { exit(1) }
    print("SMOKE OK")
    exit(0)
}

// main.swift zaten ana thread'de yürüyor; delege ana aktöre bağlı olduğu için
// bunu derleyiciye açıkça söylüyoruz.
// Tanı komutu: modeli yükleyip bir ses dosyasını çözer (GUI ve mikrofon gerekmez).
// Whisper zincirinin paketlenmiş halde de çalıştığını kanıtlamak için.
if CommandLine.arguments.dropFirst().first == "listender-ses-testi" {
    guard CommandLine.arguments.count > 2 else {
        FileHandle.standardError.write(Data("kullanım: Listender listender-ses-testi <wav>\n".utf8))
        exit(2)
    }
    let dosya = CommandLine.arguments[2]
    let bekle = DispatchSemaphore(value: 0)
    Task {
        do {
            let ornekler = try SesDosyasi.oku16kHz(dosya)
            print("ses: \(String(format: "%.1f", Double(ornekler.count) / Ayarlar.ornekleme)) sn")
            let cozumleyici = Cozumleyici { print("  \($0)") }
            let t0 = Date()
            try await cozumleyici.yukle()
            print("model hazır: \(String(format: "%.1f", Date().timeIntervalSince(t0))) sn")
            let t1 = Date()
            let ham = try await cozumleyici.cozumle(ornekler)
            print("transkript (\(String(format: "%.2f", Date().timeIntervalSince(t1))) sn): \(ham)")
            print("temiz: \(Temizleyici.regexTemizle(ham))")
        } catch {
            FileHandle.standardError.write(Data("HATA: \(error)\n".utf8))
            exit(1)
        }
        bekle.signal()
    }
    bekle.wait()
    exit(0)
}

let uygulama = NSApplication.shared
MainActor.assumeIsolated {
    let delege = UygulamaDelegesi()
    uygulama.delegate = delege
    // Delege NSApplication tarafından zayıf tutulur; süreç boyunca yaşasın.
    Sabitler.delege = delege
}
uygulama.setActivationPolicy(.accessory)   // menü barı uygulaması, Dock'ta görünmez
uygulama.run()

/// Delegeyi hayatta tutan tek referans.
enum Sabitler {
    nonisolated(unsafe) static var delege: UygulamaDelegesi?
}
