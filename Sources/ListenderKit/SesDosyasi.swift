import AVFoundation
import Foundation

/// Ses dosyasını whisper'ın istediği 16 kHz mono float32 diziye çevirir.
/// Yalnız tanı komutu (`listender-ses-testi`) kullanıyor; canlı dikte akışında
/// ses hiçbir zaman diske uğramaz.
public enum SesDosyasi {

    public static func oku16kHz(_ yol: String) throws -> [Float] {
        let dosya = try AVAudioFile(forReading: URL(fileURLWithPath: yol))
        let kaynak = dosya.processingFormat

        guard let hedef = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Ayarlar.ornekleme,
            channels: 1,
            interleaved: false) else { throw Hata.bicimKurulamadi }

        guard let girdi = AVAudioPCMBuffer(
            pcmFormat: kaynak, frameCapacity: AVAudioFrameCount(dosya.length)) else {
            throw Hata.tamponKurulamadi
        }
        try dosya.read(into: girdi)

        // Zaten istenen biçimdeyse dönüştürmeye gerek yok.
        if kaynak.sampleRate == Ayarlar.ornekleme, kaynak.channelCount == 1,
           let veri = girdi.floatChannelData?[0] {
            return Array(UnsafeBufferPointer(start: veri, count: Int(girdi.frameLength)))
        }

        guard let donusturucu = AVAudioConverter(from: kaynak, to: hedef) else {
            throw Hata.donusturucuKurulamadi
        }
        let oran = hedef.sampleRate / kaynak.sampleRate
        let kapasite = AVAudioFrameCount(Double(girdi.frameLength) * oran) + 1024
        guard let cikti = AVAudioPCMBuffer(pcmFormat: hedef, frameCapacity: kapasite) else {
            throw Hata.tamponKurulamadi
        }

        var verildi = false
        var hata: NSError?
        donusturucu.convert(to: cikti, error: &hata) { _, durum in
            if verildi { durum.pointee = .endOfStream; return nil }
            verildi = true
            durum.pointee = .haveData
            return girdi
        }
        if let hata { throw hata }

        guard let veri = cikti.floatChannelData?[0] else { throw Hata.tamponKurulamadi }
        return Array(UnsafeBufferPointer(start: veri, count: Int(cikti.frameLength)))
    }

    // MARK: Teşhis yazımı

    /// Boş dönen kayıtların saklandığı klasör. Kullanıcının sesi **yalnız**
    /// buraya, **yalnız** transkript boş döndüğünde yazılır; canlı dikte
    /// akışında ses hiçbir zaman diske uğramaz.
    public static var bosKayitKlasoru: URL {
        Ayarlar.logDosyasi.deletingLastPathComponent()
            .appendingPathComponent("bos-kayitlar", isDirectory: true)
    }

    /// 16 kHz mono float32 diziyi wav olarak yazar ve yazılan yolu döndürür.
    @discardableResult
    public static func wavYaz(_ ornekler: [Float], _ hedef: URL) throws -> URL {
        // Boş dizide yazacak örnek yok; `frameCapacity: max(ornekler.count, 1)`
        // ile `frameLength: ornekler.count` (0) arasındaki uyumsuzluğu erkenden
        // kes, sıfır örnekli bir wav dosyası oluşturmayı dene.
        guard !ornekler.isEmpty else { throw Hata.bosOrnekDizisi }

        guard let bicim = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Ayarlar.ornekleme,
            channels: 1,
            interleaved: false) else { throw Hata.bicimKurulamadi }

        try FileManager.default.createDirectory(
            at: hedef.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Float32 wav her oynatıcıda açılmıyor; dosya 16 bit tamsayı yazılır,
        // okurken zaten AVAudioFile float'a çeviriyor.
        let ayarlar: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: Ayarlar.ornekleme,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let dosya = try AVAudioFile(forWriting: hedef, settings: ayarlar)

        guard let tampon = AVAudioPCMBuffer(
            pcmFormat: bicim, frameCapacity: AVAudioFrameCount(ornekler.count)),
            let veri = tampon.floatChannelData?[0] else { throw Hata.tamponKurulamadi }

        for (i, deger) in ornekler.enumerated() { veri[i] = deger }
        tampon.frameLength = AVAudioFrameCount(ornekler.count)
        try dosya.write(from: tampon)
        return hedef
    }

    /// Boş dönen kaydı teşhis klasörüne yazar ve klasörü `enFazla` dosyayla
    /// sınırlar (en eskisi silinir). Hata olursa yutulur — teşhis yazımı
    /// dikteyi hiçbir zaman bozmaz.
    @discardableResult
    public static func bosKaydiSakla(
        _ ornekler: [Float], zaman: Date = Date(), enFazla: Int = 20
    ) -> URL? {
        guard !ornekler.isEmpty else { return nil }

        let bicimlendirici = DateFormatter()
        bicimlendirici.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let taban = bicimlendirici.string(from: zaman)
        let hedef = benzersizHedef(taban: taban)

        do {
            try wavYaz(ornekler, hedef)
        } catch {
            Gunluk.yaz("boş kayıt saklanamadı: \(error.localizedDescription)")
            return nil
        }

        eskileriSil(enFazla: enFazla)
        return hedef
    }

    /// `taban` adıyla henüz var olmayan bir dosya yolu üretir. Milisaniye
    /// çözünürlüğü aynı saniyedeki çakışmaları çoğunlukla önlüyor ama aynı
    /// milisaniyede iki boş kayıt gelirse (örn. testte) `-2`, `-3` eki eklenir.
    private static func benzersizHedef(taban: String) -> URL {
        let yonetici = FileManager.default
        var aday = bosKayitKlasoru.appendingPathComponent("\(taban).wav")
        var sira = 2
        while yonetici.fileExists(atPath: aday.path) {
            aday = bosKayitKlasoru.appendingPathComponent("\(taban)-\(sira).wav")
            sira += 1
        }
        return aday
    }

    /// Klasörde en fazla `enFazla` wav bırakır, fazlasını eskiden başlayarak siler.
    static func eskileriSil(enFazla: Int) {
        let yonetici = FileManager.default
        guard let icerik = try? yonetici.contentsOfDirectory(
            at: bosKayitKlasoru,
            includingPropertiesForKeys: [.contentModificationDateKey]) else { return }

        let wavlar = icerik.filter { $0.pathExtension.lowercased() == "wav" }
        guard wavlar.count > enFazla else { return }

        let sirali = wavlar.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return a < b
        }
        for dosya in sirali.prefix(wavlar.count - enFazla) {
            try? yonetici.removeItem(at: dosya)
        }
    }

    public enum Hata: LocalizedError {
        case bicimKurulamadi, tamponKurulamadi, donusturucuKurulamadi, bosOrnekDizisi
        public var errorDescription: String? {
            switch self {
            case .bicimKurulamadi: return "Ses biçimi kurulamadı."
            case .tamponKurulamadi: return "Ses tamponu kurulamadı."
            case .donusturucuKurulamadi: return "Ses dönüştürücüsü kurulamadı."
            case .bosOrnekDizisi: return "Boş örnek dizisi wav olarak yazılamaz."
            }
        }
    }
}
