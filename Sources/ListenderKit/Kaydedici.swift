import AVFoundation
import Foundation

/// Ses yakalama — AVAudioEngine girişi + pre-roll halka tamponu.
///
/// Mikrofon sürekli açık dinlenir; ses küçük bir halka tamponda daima taze tutulur.
/// Kayıt başlayınca bu pre-roll ilk parça olarak alınır, böylece tuşa basmadan
/// hemen önceki ses de girer ve **ilk hece yutulmaz**.
///
/// Donanım genelde 44,1 veya 48 kHz veriyor; whisper 16 kHz mono float32 istiyor.
/// Dönüşüm `AVAudioConverter` ile tap içinde yapılır. Ses diske hiç yazılmaz.
public final class Kaydedici {

    /// Blok boyu 30 ms — düşük gecikme, makul callback yükü.
    private static let blokOrnek = AVAudioFrameCount(Ayarlar.ornekleme * 0.03)

    private let motor = AVAudioEngine()
    private var donusturucu: AVAudioConverter?
    private let hedefBicim = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Ayarlar.ornekleme,
        channels: 1,
        interleaved: false)!

    private let kilit = NSLock()
    private var kayitta = false
    private var parcalar: [[Float]] = []
    private var preRoll: [[Float]] = []
    private var preRollEnFazla: Int
    private var kayitliOrnek = 0
    private var sinirGeriCagrisi: (() -> Void)?
    /// Son tap zamanı — akış gerçekten sürüyor mu, tek güvenilir sinyal bu.
    private var sonBlokZamani = Date.distantPast

    private var akisAcik = false

    public init() {
        let blokSaniye = Double(Self.blokOrnek) / Ayarlar.ornekleme
        preRollEnFazla = max(1, Int(Ayarlar.preRollSaniye / blokSaniye))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(yapilandirmaDegisti),
            name: .AVAudioEngineConfigurationChange,
            object: motor)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: Akış

    public var akisVar: Bool { akisAcik }

    /// Akış gerçekten ses taşıyor mu. Mikrofon fiziken çekilince motor hata
    /// vermeden susabiliyor; tek güvenilir işaret tap akışının durmasıdır.
    public func akisCanli(zamanAsimi: TimeInterval = 1.5) -> Bool {
        guard akisAcik else { return false }
        return Date().timeIntervalSince(sonBlokZamani) < zamanAsimi
    }

    /// Sistemde kullanılabilir bir giriş aygıtı var mı.
    public static func girisAygitiVarMi() -> Bool {
        let motor = AVAudioEngine()
        let bicim = motor.inputNode.inputFormat(forBus: 0)
        return bicim.channelCount > 0 && bicim.sampleRate > 0
    }

    public func akisiBaslat() throws {
        guard !akisAcik else { return }

        let giris = motor.inputNode
        let kaynakBicim = giris.inputFormat(forBus: 0)
        guard kaynakBicim.channelCount > 0, kaynakBicim.sampleRate > 0 else {
            throw Hata.girisYok
        }

        donusturucu = AVAudioConverter(from: kaynakBicim, to: hedefBicim)
        guard donusturucu != nil else { throw Hata.donusturucuKurulamadi }

        // Tap boyu kaynak örneklemesinde istenir; 30 ms karşılığını hesapla.
        let tapBoyu = AVAudioFrameCount(kaynakBicim.sampleRate * 0.03)
        giris.installTap(onBus: 0, bufferSize: tapBoyu, format: kaynakBicim) { [weak self] tampon, _ in
            self?.tampondanAl(tampon)
        }

        motor.prepare()
        sonBlokZamani = Date()   // ilk tap gelene kadar ölü sayma
        try motor.start()
        akisAcik = true
        Gunluk.yaz("mikrofon akışı açıldı: \(Int(kaynakBicim.sampleRate)) Hz, \(kaynakBicim.channelCount) kanal")
    }

    public func akisiDurdur() {
        guard akisAcik else { return }
        motor.inputNode.removeTap(onBus: 0)
        motor.stop()
        donusturucu = nil
        akisAcik = false
    }

    /// Aygıt değişince (mikrofon takıldı/çekildi) motor yeniden kurulmalı.
    @objc private func yapilandirmaDegisti() {
        Gunluk.yaz("ses yapılandırması değişti — akış yeniden kurulacak")
        akisiDurdur()
    }

    // MARK: Tap

    private func tampondanAl(_ tampon: AVAudioPCMBuffer) {
        sonBlokZamani = Date()
        guard let donusturucu, let ornekler = donustur(tampon, donusturucu) else { return }

        kilit.lock()
        defer { kilit.unlock() }

        if kayitta {
            parcalar.append(ornekler)
            kayitliOrnek += ornekler.count
            if Double(kayitliOrnek) >= Ayarlar.enUzunKayitSaniye * Ayarlar.ornekleme,
               let geriCagri = sinirGeriCagrisi {
                sinirGeriCagrisi = nil
                DispatchQueue.global().async(execute: geriCagri)
            }
        } else {
            preRoll.append(ornekler)
            if preRoll.count > preRollEnFazla { preRoll.removeFirst() }
        }
    }

    /// Donanım biçimindeki tamponu 16 kHz mono float32 diziye çevirir.
    private func donustur(_ girdi: AVAudioPCMBuffer, _ donusturucu: AVAudioConverter) -> [Float]? {
        let oran = hedefBicim.sampleRate / girdi.format.sampleRate
        let kapasite = AVAudioFrameCount(Double(girdi.frameLength) * oran) + 64
        guard let cikti = AVAudioPCMBuffer(pcmFormat: hedefBicim, frameCapacity: kapasite) else {
            return nil
        }

        var verildi = false
        var hata: NSError?
        donusturucu.convert(to: cikti, error: &hata) { _, durum in
            if verildi {
                durum.pointee = .noDataNow
                return nil
            }
            verildi = true
            durum.pointee = .haveData
            return girdi
        }
        if let hata {
            Gunluk.yaz("dönüştürme hatası: \(hata.localizedDescription)")
            return nil
        }
        guard let veri = cikti.floatChannelData?[0], cikti.frameLength > 0 else { return nil }
        return Array(UnsafeBufferPointer(start: veri, count: Int(cikti.frameLength)))
    }

    // MARK: Kayıt

    /// Kaydı başlat. `sinirAsildi` üst süre sınırı aşılınca çağrılır.
    public func kaydiBaslat(sinirAsildi: (() -> Void)? = nil) {
        kilit.lock()
        defer { kilit.unlock() }
        guard !kayitta else { return }
        parcalar = preRoll               // pre-roll ilk parça olarak girer
        kayitliOrnek = parcalar.reduce(0) { $0 + $1.count }
        kayitta = true
        sinirGeriCagrisi = sinirAsildi
    }

    /// Kaydı bitir ve biriken sesi tek dizi olarak döndür.
    public func kaydiBitir() -> [Float] {
        kilit.lock()
        defer { kilit.unlock() }
        kayitta = false
        sinirGeriCagrisi = nil
        let toplanan = parcalar
        parcalar = []
        kayitliOrnek = 0
        return toplanan.flatMap { $0 }
    }

    public enum Hata: LocalizedError {
        case girisYok
        case donusturucuKurulamadi

        public var errorDescription: String? {
            switch self {
            case .girisYok: return "Kullanılabilir mikrofon bulunamadı."
            case .donusturucuKurulamadi: return "Ses dönüştürücüsü kurulamadı."
            }
        }
    }
}
