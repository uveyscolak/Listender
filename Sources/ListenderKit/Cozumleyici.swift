import Foundation
import WhisperKit

/// Whisper motoru — WhisperKit (CoreML, Apple Silicon'da Neural Engine).
///
/// Model uygulama açılışında **bir kez** yüklenir ve bellekte sıcak tutulur;
/// dikte akışında her çağrıda yükleme deseni işlemez. Açılışta kısa bir ısınma
/// çıkarımı yapılır ki ilk gerçek dikte de hızlı olsun.
///
/// Ses diske hiç yazılmaz: 16 kHz float32 dizi doğrudan motora verilir.
public final class Cozumleyici: @unchecked Sendable {

    private var whisper: WhisperKit?
    private let durumBildir: @Sendable (String) -> Void

    public init(durumBildir: @escaping @Sendable (String) -> Void = { _ in }) {
        self.durumBildir = durumBildir
    }

    public var yuklendiMi: Bool { whisper != nil }

    /// Modeli indir (ilk açılışta, ~1,5 GB), belleğe al ve ısıt.
    public func yukle() async throws {
        try FileManager.default.createDirectory(
            at: Ayarlar.modelKlasoru, withIntermediateDirectories: true)

        // İlk açılışta iki ayrı bekleme var: model indirme (~1,5 GB) ve CoreML'in
        // modeli bu uygulama için derlemesi (~2 dk, ölçüldü). İkincisi kuruluma
        // özgü, sonraki açılışlar ~7 sn. Kullanıcı ne beklediğini bilsin.
        let modelVar = modelDiskteVarMi()
        durumBildir(modelVar
            ? "Model hazırlanıyor… (ilk açılışta birkaç dakika sürebilir)"
            : "Model indiriliyor (bir kez, ~1,5 GB)…")

        let yapilandirma = WhisperKitConfig(
            model: Ayarlar.modelAdi,
            downloadBase: Ayarlar.modelKlasoru,
            prewarm: true,
            load: true,
            download: true)

        let motor = try await WhisperKit(yapilandirma)
        whisper = motor

        // Isınma: 1 sn sessizlik çöz, CoreML/ANE hattını ısıt. Hatası kritik değil.
        durumBildir("Isınıyor…")
        let sessizlik = [Float](repeating: 0, count: Int(Ayarlar.ornekleme))
        _ = try? await motor.transcribe(audioArray: sessizlik, decodeOptions: cozmeSecenekleri())

        durumBildir("Hazır")
        Gunluk.yaz("model hazır: \(Ayarlar.modelAdi)")
    }

    /// 16 kHz mono float32 diziyi Türkçe metne çevirir.
    public func cozumle(_ ornekler: [Float]) async throws -> String {
        try await cozumleAyrintili(ornekler).metin
    }

    /// Çözümlemenin metni ve teşhis ayrıntısı. Boş dönüşün sebebini bir dahaki
    /// sefere tek bakışta görebilmek için segment ölçümleri de taşınır.
    public struct Sonuc: Sendable {
        public var metin: String
        public var dil: String
        public var segmentler: [SegmentOlcumu]
    }

    /// Bir segmentin karar ölçümleri. Boş transkriptin sebebi bu üç sayıda saklı:
    /// `avgLogprob` düşükse model emin değil, `compressionRatio` yüksekse tekrar
    /// döngüsüne girmiş, `temperature` sıfırdan büyükse fallback devreye girmiş.
    public struct SegmentOlcumu: Sendable {
        public var noSpeechProb: Float
        public var avgLogprob: Float
        public var compressionRatio: Float
        public var temperature: Float
        public var karakterSayisi: Int
    }

    public func cozumleAyrintili(_ ornekler: [Float]) async throws -> Sonuc {
        guard let whisper else { throw Hata.modelYuklenmedi }

        let hazir = tepeNormalize(ornekler)
        let sonuclar: [TranscriptionResult] = try await whisper.transcribe(
            audioArray: hazir, decodeOptions: cozmeSecenekleri())

        let metin = sonuclar
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let segmentler = sonuclar.flatMap(\.segments).map {
            SegmentOlcumu(
                noSpeechProb: $0.noSpeechProb,
                avgLogprob: $0.avgLogprob,
                compressionRatio: $0.compressionRatio,
                temperature: $0.temperature,
                karakterSayisi: $0.text.trimmingCharacters(in: .whitespacesAndNewlines).count)
        }

        return Sonuc(
            metin: metin,
            dil: sonuclar.first?.language ?? Ayarlar.dil,
            segmentler: segmentler)
    }

    /// Çözme seçenekleri.
    ///
    /// `promptTokens` bilerek kullanılmıyor. Python sürümü noktalama tutarlılığı
    /// için `initial_prompt` veriyordu; WhisperKit'te bu seçenek prefill
    /// önbelleğiyle birlikte bozuk — kendi kaynağında da not düşülmüş
    /// (TextDecoder.swift: "currently breaks if it starts at non-zero index").
    /// Denendi: prompt verilince transkript boş dönüyordu. large-v3-turbo zaten
    /// kendiliğinden düzgün noktalıyor, prompt'a gerek kalmadı.
    /// Bkz. brain/Kararlar 2026-09-02.
    ///
    /// **`firstTokenLogProbThreshold: nil` — dolu sese rağmen boş dönen
    /// transkriptin sebebi buydu (2026-09-13'te WhisperKit kaynağından
    /// kanıtlandı).** WhisperKit'in varsayılanı -1,5; çözme döngüsü ilk gerçek
    /// token'ın log olasılığı bu değerin altına düşerse döngüyü hiç token
    /// toplamadan kırıyor (TextDecoder.swift:852-868, `break` satırı
    /// `currentTokens.append`'den önce). Geriye yalnız prefill özel token'ları
    /// kalıyor, onlar da elendiğinde metin boş string oluyor. Devreye giren
    /// sıcaklık fallback'i de kurtarmıyor: altı denemenin hepsi aynı eşiğe
    /// çarpıyor ve TranscribeTask.swift:380 **son** denemeyi döndürüyor, en
    /// iyisini değil. Türkçe konuşmanın ilk token'ı doğal olarak belirsiz
    /// olabildiği için eşik gerçek konuşmayı eliyordu.
    ///
    /// Türkçe zorlaması korunuyor: `usePrefillPrompt: true` kalmalı, çünkü dil
    /// token'ı (`<|tr|>`) yalnız prefill yoluyla basılıyor
    /// (TextDecoder.swift:323-325) ve `usePrefillPrompt: false` verilirse
    /// `detectLanguage` kendiliğinden açılıp dili modele seçtiriyor
    /// (Configurations.swift:226). Bu yüzden çözüm prefill'i kapatmak değil,
    /// yalnız erken çıkış eşiğini kaldırmak.
    ///
    /// `compressionRatioThreshold` (2,4) ve `logProbThreshold` (-1,0)
    /// varsayılanda bırakıldı: ikisi de tekrar döngüsüne ve çöp çıktıya karşı
    /// gerçek koruma, belirtiyle ilgileri yok.
    private func cozmeSecenekleri() -> DecodingOptions {
        DecodingOptions(
            task: .transcribe,                  // dikte, çeviri değil
            language: Ayarlar.dil,              // sabit Türkçe, otomatik algılama yok
            usePrefillPrompt: true,             // <|tr|> token'ını zorlar — KAPATILMAMALI
            detectLanguage: false,              // dil zaten sabit, tespit turu gereksiz
            firstTokenLogProbThreshold: nil)    // boş transkriptin kök nedeni; bkz. üstteki not
    }

    /// Kablosuz mikrofon çok kısık gelebiliyor (canlı ölçüm: konuşma RMS ~0,009).
    /// Sesi whisper'ın rahat çözdüğü tepe seviyeye çeker.
    func tepeNormalize(_ ornekler: [Float]) -> [Float] {
        guard let tepe = ornekler.map(abs).max(), tepe > 0 else { return ornekler }
        let katsayi = Ayarlar.normalizeTepe / tepe
        return ornekler.map { $0 * katsayi }
    }

    private func modelDiskteVarMi() -> Bool {
        guard let icerik = try? FileManager.default.contentsOfDirectory(
            at: Ayarlar.modelKlasoru, includingPropertiesForKeys: nil) else { return false }
        return !icerik.isEmpty
    }

    public enum Hata: LocalizedError {
        case modelYuklenmedi
        public var errorDescription: String? {
            switch self {
            case .modelYuklenmedi: return "Model henüz yüklenmedi."
            }
        }
    }
}

/// Sesin ortalama gücü (RMS). Sessizlik kapısı bununla ölçülür.
public func rmsHesapla(_ ornekler: [Float]) -> Float {
    guard !ornekler.isEmpty else { return 0 }
    let kareToplam = ornekler.reduce(Float(0)) { $0 + $1 * $1 }
    return (kareToplam / Float(ornekler.count)).squareRoot()
}
