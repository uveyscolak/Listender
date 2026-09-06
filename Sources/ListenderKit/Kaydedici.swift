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

        // Dönüştürücü mono→mono kurulur (kaynak örneklemesinde); çok kanallı
        // girişler `kanallariOrtala` ile önce elle mono'ya indirgenir. Sebep:
        // AVAudioConverter'a doğrudan N-kanallı format verilirse, kanal düzeni
        // (layout) tanımsız donanımlarda (çoğu USB ses kartı) hangi kanalı
        // aldığı belirsiz — sessiz bir kanalı seçip tam sessizlik üretebiliyor.
        let araBicim = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: kaynakBicim.sampleRate,
            channels: 1,
            interleaved: false)!
        donusturucu = AVAudioConverter(from: araBicim, to: hedefBicim)
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

    /// Kaynak N kanallıysa hepsini ortalayarak tek kanala indirger — hangi giriş
    /// aygıtı aktifse o kullanılmalı, kanal sayısı önemli olmamalı. Zaten mono
    /// gelen tamponlara dokunmadan geçer.
    ///
    /// AVAudioConverter'a doğrudan çok kanallı format verildiğinde kanal düzeni
    /// (layout) tanımsız donanımlarda (çoğu USB ses kartı, ör. PreSonus Revelator)
    /// hangi kanalı okuduğu belirsiz kalıyor — konuşma başka bir kanaldayken
    /// sessiz bir kanalı seçip tam sessizlik (RMS 0) üretebiliyor. Kanalları
    /// elle ortalamak bu belirsizliği ortadan kaldırır: hangi kanalda ses varsa
    /// toplama girer.
    private func kanallariOrtala(_ girdi: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let kanalSayisi = Int(girdi.format.channelCount)
        guard kanalSayisi > 1 else { return girdi }

        guard let kaynakVeri = girdi.floatChannelData else { return nil }
        let uzunluk = Int(girdi.frameLength)
        guard uzunluk > 0 else { return nil }

        let monoBicim = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: girdi.format.sampleRate,
            channels: 1,
            interleaved: false)!
        guard let cikti = AVAudioPCMBuffer(pcmFormat: monoBicim, frameCapacity: AVAudioFrameCount(uzunluk)),
              let hedefVeri = cikti.floatChannelData?[0]
        else { return nil }

        for orn in 0..<uzunluk {
            var toplam: Float = 0
            for k in 0..<kanalSayisi { toplam += kaynakVeri[k][orn] }
            hedefVeri[orn] = toplam / Float(kanalSayisi)
        }
        cikti.frameLength = AVAudioFrameCount(uzunluk)
        return cikti
    }

    /// Donanım biçimindeki tamponu 16 kHz mono float32 diziye çevirir.
    private func donustur(_ girdiHam: AVAudioPCMBuffer, _ donusturucu: AVAudioConverter) -> [Float]? {
        guard let girdi = kanallariOrtala(girdiHam) else { return nil }

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
