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
        guard let whisper else { throw Hata.modelYuklenmedi }

        let hazir = tepeNormalize(ornekler)
        let sonuclar: [TranscriptionResult] = try await whisper.transcribe(
            audioArray: hazir, decodeOptions: cozmeSecenekleri())

        return sonuclar
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
    private func cozmeSecenekleri() -> DecodingOptions {
        DecodingOptions(
            language: Ayarlar.dil,      // sabit Türkçe, otomatik algılama yok
            usePrefillPrompt: true)
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
