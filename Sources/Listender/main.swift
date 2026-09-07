import AppKit
import AVFoundation
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

// Tanı komutu: canlı mikrofonu dinler ve HER KANALIN sinyal seviyesini ayrı
// ayrı raporlar. Amaç, "ses gelmiyor" şikâyetinde sorunun nerede olduğunu
// kesinleştirmek: donanım hiç sinyal vermiyor mu, yoksa sinyal belirli bir
// kanalda mı (çok kanallı USB ses kartlarında olağan) ve mono'ya indirgeme
// onu koruyor mu. GUI, tuş dinleyici ve Erişilebilirlik izni gerektirmez.
if CommandLine.arguments.dropFirst().first == "listender-mikrofon-testi" {
    let saniye = Double(CommandLine.arguments.dropFirst(2).first ?? "5") ?? 5

    let motor = AVAudioEngine()
    let giris = motor.inputNode
    let bicim = giris.inputFormat(forBus: 0)
    guard bicim.channelCount > 0, bicim.sampleRate > 0 else {
        FileHandle.standardError.write(Data("HATA: kullanılabilir giriş aygıtı yok\n".utf8))
        exit(1)
    }

    let kanalSayisi = Int(bicim.channelCount)
    print("giriş: \(Int(bicim.sampleRate)) Hz, \(kanalSayisi) kanal")
    print("\(String(format: "%.0f", saniye)) saniye boyunca konuşun…")

    let kilit = NSLock()
    var kareToplami = [Double](repeating: 0, count: kanalSayisi)   // kanal başına Σx²
    var tepe = [Float](repeating: 0, count: kanalSayisi)           // kanal başına |x| tepe
    var monoKareToplami: Double = 0                                // ortalanmış mono Σx²
    var ornekSayisi = 0

    giris.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bicim.sampleRate * 0.1), format: bicim) { tampon, _ in
        guard let veri = tampon.floatChannelData else { return }
        let uzunluk = Int(tampon.frameLength)
        guard uzunluk > 0 else { return }

        kilit.lock()
        defer { kilit.unlock() }
        for orn in 0..<uzunluk {
            var toplam: Float = 0
            for k in 0..<kanalSayisi {
                let deger = veri[k][orn]
                kareToplami[k] += Double(deger) * Double(deger)
                tepe[k] = max(tepe[k], abs(deger))
                toplam += deger
            }
            let mono = toplam / Float(kanalSayisi)
            monoKareToplami += Double(mono) * Double(mono)
        }
        ornekSayisi += uzunluk
    }

    do {
        motor.prepare()
        try motor.start()
    } catch {
        FileHandle.standardError.write(Data("HATA: ses motoru başlamadı: \(error)\n".utf8))
        exit(1)
    }

    Thread.sleep(forTimeInterval: saniye)
    motor.stop()
    giris.removeTap(onBus: 0)

    kilit.lock()
    let n = max(ornekSayisi, 1)
    print("\ntoplanan örnek: \(ornekSayisi)")
    print("\nkanal başına seviye:")
    var sesliKanallar: [Int] = []
    for k in 0..<kanalSayisi {
        let rms = (kareToplami[k] / Double(n)).squareRoot()
        let isaret = rms > 0.0005 ? "  ← SİNYAL VAR" : ""
        if rms > 0.0005 { sesliKanallar.append(k + 1) }
        print(String(format: "  kanal %d: RMS=%.6f  tepe=%.6f%@", k + 1, rms, tepe[k], isaret))
    }
    let monoRms = (monoKareToplami / Double(n)).squareRoot()
    print(String(format: "\nkanalların ortalaması (uygulamanın kullandığı): RMS=%.6f", monoRms))
    kilit.unlock()

    print("")
    if sesliKanallar.isEmpty {
        print("SONUÇ: hiçbir kanalda sinyal yok — donanım/izin sorunu.")
        print("  · Terminal'in mikrofon izni var mı (Gizlilik → Mikrofon)?")
        print("  · Sistem Ayarları → Ses → Giriş'te doğru aygıt seçili ve seviye çubuğu oynuyor mu?")
    } else {
        print("SONUÇ: sinyal şu kanallarda: \(sesliKanallar.map(String.init).joined(separator: ", "))")
        if monoRms > 0.0005 {
            print("  Ortalama mono sinyali koruyor — kayıt zinciri bu girişle çalışmalı.")
        } else {
            print("  UYARI: kanallarda ses var ama ortalama sıfıra yakın (kanallar birbirini götürüyor olabilir).")
        }
    }
    exit(0)
}

// IOLLEvent.h'daki cihaza özel değiştirici tuş bit maskeleri: hangi tarafın
// (sol/sağ) basılı olduğunu ayırt etmek için kullanılır.
private let NX_DEVICELCTLKEYMASK: UInt64 = 0x00000001
private let NX_DEVICELSHIFTKEYMASK: UInt64 = 0x00000002
private let NX_DEVICERSHIFTKEYMASK: UInt64 = 0x00000004
private let NX_DEVICELCMDKEYMASK: UInt64 = 0x00000008
private let NX_DEVICERCMDKEYMASK: UInt64 = 0x00000010
private let NX_DEVICELALTKEYMASK: UInt64 = 0x00000020
private let NX_DEVICERALTKEYMASK: UInt64 = 0x00000040
private let NX_DEVICERCTLKEYMASK: UInt64 = 0x00002000

// Sol/sağ bitlerine göre "(sol)", "(sağ)" ya da "(sol+sağ)" eki üretir.
private func tarafEki(sol: Bool, sag: Bool) -> String {
    if sol && sag { return "(sol+sağ)" }
    if sag { return "(sağ)" }
    if sol { return "(sol)" }
    return ""
}

// Tanı komutu: değiştirici tuş olaylarını ham haliyle yazar. "Tuşa basıyorum
// ama uygulama görmüyor" şikâyetinde iki ihtimali ayırır: olaylar hiç gelmiyor
// (izin/tap sorunu) mu, yoksa geliyor da beklenen tuş kodu tutmuyor mu
// (klavye farkı). Terminal'den çalıştırılır; izin Terminal'e sorulur.
if CommandLine.arguments.dropFirst().first == "listender-tus-testi" {
    let saniye = Double(CommandLine.arguments.dropFirst(2).first ?? "15") ?? 15

    let geriCagri: CGEventTapCallBack = { _, tur, olay, _ in
        if tur == .tapDisabledByTimeout || tur == .tapDisabledByUserInput {
            print("  ! tap sistem tarafından kapatıldı")
            return Unmanaged.passUnretained(olay)
        }
        let kod = olay.getIntegerValueField(.keyboardEventKeycode)
        let bayraklar = olay.flags
        let ham = UInt64(bayraklar.rawValue)
        var adlar: [String] = []
        if bayraklar.contains(.maskAlternate) {
            adlar.append("⌥" + tarafEki(sol: ham & NX_DEVICELALTKEYMASK != 0,
                                         sag: ham & NX_DEVICERALTKEYMASK != 0))
        }
        if bayraklar.contains(.maskCommand) {
            adlar.append("⌘" + tarafEki(sol: ham & NX_DEVICELCMDKEYMASK != 0,
                                         sag: ham & NX_DEVICERCMDKEYMASK != 0))
        }
        if bayraklar.contains(.maskControl) {
            adlar.append("⌃" + tarafEki(sol: ham & NX_DEVICELCTLKEYMASK != 0,
                                         sag: ham & NX_DEVICERCTLKEYMASK != 0))
        }
        if bayraklar.contains(.maskShift) {
            adlar.append("⇧" + tarafEki(sol: ham & NX_DEVICELSHIFTKEYMASK != 0,
                                         sag: ham & NX_DEVICERSHIFTKEYMASK != 0))
        }
        if bayraklar.contains(.maskSecondaryFn) { adlar.append("fn") }
        let bilinen: String
        switch kod {
        case 58: bilinen = "sol ⌥"
        case 61: bilinen = "SAĞ ⌥  ← uygulamanın beklediği tuş"
        case 55: bilinen = "sol ⌘"
        case 54: bilinen = "sağ ⌘"
        case 59: bilinen = "sol ⌃"
        case 62: bilinen = "sağ ⌃"
        case 56: bilinen = "sol ⇧"
        case 60: bilinen = "sağ ⇧"
        case 63: bilinen = "fn"
        default: bilinen = "?"
        }
        var satir = "  tuş kodu \(kod)  [\(bilinen)]  bayraklar: \(adlar.isEmpty ? "—" : adlar.joined(separator: " "))"
        if kod == 61 {
            let sagOptionBasili = ham & NX_DEVICERALTKEYMASK != 0
            satir += sagOptionBasili ? "  → uygulama KAYIT BAŞLATIR" : "  → uygulama KAYIT DURDURUR"
        }
        print(satir)
        fflush(stdout)   // dosyaya yönlendirildiğinde tampon beklemesin
        return Unmanaged.passUnretained(olay)
    }

    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,
        eventsOfInterest: CGEventMask(1 << CGEventType.flagsChanged.rawValue),
        callback: geriCagri,
        userInfo: nil)
    else {
        FileHandle.standardError.write(Data(
            "HATA: tap kurulamadı — Terminal'e Giriş İzleme izni verin\n".utf8))
        exit(1)
    }

    let kaynak = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), kaynak, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)

    print("tap kuruldu. \(String(format: "%.0f", saniye)) saniye boyunca")
    print("değiştirici tuşlara (⌥ ⌘ ⌃ ⇧) tek tek basıp bırakın:")
    print("Sağ ⌥ tuşuna basıp bırakın. Ayrıca sol ⌥ basılıyken sağ ⌥'ye basıp bırakmayı deneyin — ikisi birlikteyken de doğru çalışmalı.\n")
    fflush(stdout)
    CFRunLoopRunInMode(.defaultMode, saniye, false)
    print("\nbitti.")
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
