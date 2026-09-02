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

    public enum Hata: LocalizedError {
        case bicimKurulamadi, tamponKurulamadi, donusturucuKurulamadi
        public var errorDescription: String? {
            switch self {
            case .bicimKurulamadi: return "Ses biçimi kurulamadı."
            case .tamponKurulamadi: return "Ses tamponu kurulamadı."
            case .donusturucuKurulamadi: return "Ses dönüştürücüsü kurulamadı."
            }
        }
    }
}
