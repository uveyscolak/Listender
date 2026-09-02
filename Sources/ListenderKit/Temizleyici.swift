import Foundation

/// Metin temizliği — iki aşama.
///
/// 1. **Regex** (her zaman): dolgu token'larını sil, yumuşak dolguları cümle
///    başında ve ardışık tekrarda temizle, boşluk/noktalama düzelt, whisper'ın
///    sessizlikte ürettiği bilinen halüsinasyonları at.
/// 2. **Ollama** (opsiyonel): noktalama ve akıcılık düzeltmesi. Erişilemezse
///    sessizce regex sonucuna düşer — LLM hiçbir zaman zorunlu değil.
public enum Temizleyici {

    // MARK: Aşama 1 — regex

    /// Türkçe'ye uygun küçültme.
    ///
    /// Swift'in (ve Python'un) `lowercased()`'i İngilizce kurallarını uygular:
    /// "İ" -> "i" + birleşen nokta (U+0307), "I" -> "i". Türkçe'de doğrusu
    /// "İ" -> "i" ve "I" -> "ı". Bu fark yüzünden halüsinasyon filtresi cümle
    /// başındaki büyük harfli kalıpları hiç yakalayamıyordu (Python sürümünde de
    /// aynı kusur vardı; testle yakalandı, 2026-09-02).
    static func turkceKucult(_ metin: String) -> String {
        var sonuc = ""
        for harf in metin {
            switch harf {
            case "İ": sonuc += "i"
            case "I": sonuc += "ı"
            case "Ğ": sonuc += "ğ"
            case "Ü": sonuc += "ü"
            case "Ş": sonuc += "ş"
            case "Ö": sonuc += "ö"
            case "Ç": sonuc += "ç"
            default: sonuc += String(harf).lowercased()
            }
        }
        return sonuc
    }

    /// Token'ı, her harfin Türkçe büyük karşılığını da kabul eden desene çevirir.
    /// `caseInsensitive` bayrağı Türkçe i/ı çiftini doğru eşleştirmiyor.
    static func turkceDesen(_ token: String) -> String {
        let buyuk: [Character: Character] = [
            "i": "İ", "ı": "I", "ş": "Ş", "ğ": "Ğ", "ü": "Ü", "ö": "Ö", "ç": "Ç",
        ]
        return token.map { harf in
            let karsilik = buyuk[harf] ?? Character(harf.uppercased())
            let a = NSRegularExpression.escapedPattern(for: String(harf))
            let b = NSRegularExpression.escapedPattern(for: String(karsilik))
            return a == b ? a : "[\(a)\(b)]"
        }.joined()
    }

    /// Tüm metin tek bir bilinen halüsinasyon kalıbından ibaretse komple at.
    static func halusinasyonAyikla(_ metin: String) -> String {
        let kucuk = turkceKucult(metin.trimmingCharacters(in: .whitespacesAndNewlines))
        let noktalama = CharacterSet(charactersIn: ".!?")
        for kalip in Ayarlar.halusinasyonKaliplari {
            if kucuk == kalip { return "" }
            let a = kucuk.trimmingCharacters(in: noktalama)
            let b = kalip.trimmingCharacters(in: noktalama)
            if a == b { return "" }
        }
        return metin
    }

    public static func regexTemizle(_ girdi: String) -> String {
        guard !girdi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }

        var metin = halusinasyonAyikla(girdi)
        if metin.isEmpty { return "" }

        // Sert dolgular: nerede geçerse geçsin sil (kelime sınırıyla).
        for token in Ayarlar.dolguTokenlari {
            metin = degistir(metin, "(?<!\\w)\(turkceDesen(token))(?!\\w)", " ")
        }

        // Yumuşak dolgular: yalnız cümle başında ve ardışık tekrarda.
        for token in Ayarlar.yumusakDolgular {
            let desen = turkceDesen(token)
            metin = degistir(metin, "(^|[.!?]\\s+)\(desen)\\b[,\\s]*", "$1")
            // Ardışık tekrarda geri referans kullanılamaz (desen harf sınıfı içeriyor),
            // aynı deseni ikinci kez yazmak aynı işi görür.
            metin = degistir(metin, "\\b(\(desen))(\\s+\(desen)\\b)+", "$1")
        }

        // Boşluk ve noktalama düzeltmeleri.
        metin = degistir(metin, "\\s+", " ")
        metin = degistir(metin, "\\s+([,.!?;:])", "$1")
        metin = degistir(metin, ",\\s*,+", ",")
        metin = degistir(metin, "^[\\s,]+", "")

        return metin.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func degistir(_ metin: String, _ kalip: String, _ yerine: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: kalip, options: [.caseInsensitive]) else {
            return metin
        }
        let aralik = NSRange(metin.startIndex..., in: metin)
        return regex.stringByReplacingMatches(in: metin, range: aralik, withTemplate: yerine)
    }

    // MARK: Tam hat

    /// `llmKullan` açık ve Ollama erişilebilirse LLM katmanını da uygular.
    public static func temizle(_ metin: String, llmKullan: Bool) async -> String {
        let temiz = regexTemizle(metin)
        guard !temiz.isEmpty else { return "" }
        guard llmKullan, await Ollama.kullanilabilir() else { return temiz }
        return await Ollama.duzelt(temiz).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Opsiyonel yerel LLM katmanı. Kurulu değilse uygulama tam çalışır.
public enum Ollama {

    /// Binary yolu; kurulu değilse nil. Finder'dan açılan `.app`'in PATH'inde
    /// /opt/homebrew/bin olmadığı için bilinen yollar elle denenir.
    public static func binaryYolu() -> String? {
        for yol in Ayarlar.ollamaBinaryYollari
        where FileManager.default.isExecutableFile(atPath: yol) {
            return yol
        }
        return nil
    }

    /// Servis ayakta mı (model şartı yok, sadece API cevabı).
    public static func servisAyaktaMi() async -> Bool {
        await etiketleriAl() != nil
    }

    /// Servis ayakta VE hedef model yüklü mü.
    public static func kullanilabilir() async -> Bool {
        guard let adlar = await etiketleriAl() else { return false }
        let taban = Ayarlar.ollamaModel.split(separator: ":").first.map(String.init) ?? Ayarlar.ollamaModel
        return adlar.contains { $0 == Ayarlar.ollamaModel || $0.hasPrefix(taban) }
    }

    private static func etiketleriAl() async -> [String]? {
        var istek = URLRequest(url: Ayarlar.ollamaURL.appendingPathComponent("api/tags"))
        istek.timeoutInterval = 1.5
        guard let (veri, _) = try? await URLSession.shared.data(for: istek),
              let kok = try? JSONSerialization.jsonObject(with: veri) as? [String: Any],
              let modeller = kok["models"] as? [[String: Any]] else { return nil }
        return modeller.compactMap { $0["name"] as? String }
    }

    /// Kuruluysa ve servis kapalıysa arka planda başlat. Kurulu değilse sessizce geç.
    public static func kuruluysaBaslat() async {
        guard let binary = binaryYolu(), await !servisAyaktaMi() else { return }
        let surec = Process()
        surec.executableURL = URL(fileURLWithPath: binary)
        surec.arguments = ["serve"]
        surec.standardOutput = FileHandle.nullDevice
        surec.standardError = FileHandle.nullDevice
        try? surec.run()   // uygulama kapanınca ollama'yı öldürme: bağımsız süreç
    }

    /// Modeli indir. Uzun sürer; ilerleme satır satır bildirilir.
    public static func modeliIndir(ilerleme: @escaping @Sendable (String) -> Void) async -> Bool {
        guard let binary = binaryYolu() else { return false }
        let surec = Process()
        surec.executableURL = URL(fileURLWithPath: binary)
        surec.arguments = ["pull", Ayarlar.ollamaModel]
        let boru = Pipe()
        surec.standardOutput = boru
        surec.standardError = boru

        do { try surec.run() } catch { return false }

        do {
            for try await satir in boru.fileHandleForReading.bytes.lines {
                let kirpik = satir.trimmingCharacters(in: .whitespacesAndNewlines)
                if !kirpik.isEmpty { ilerleme("Model indiriliyor: \(String(kirpik.prefix(60)))") }
            }
        } catch {
            Gunluk.yaz("ollama pull çıktısı okunamadı: \(error.localizedDescription)")
        }
        surec.waitUntilExit()
        return surec.terminationStatus == 0
    }

    /// qwen3'ün <think>…</think> bloklarını at.
    static func dusunmeyiAyikla(_ metin: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "<think>.*?</think>", options: [.dotMatchesLineSeparators]) else { return metin }
        let aralik = NSRange(metin.startIndex..., in: metin)
        return regex.stringByReplacingMatches(in: metin, range: aralik, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Metni LLM ile düzelt. Herhangi bir hata olursa girdiyi aynen döndürür —
    /// LLM katmanı hiçbir zaman dikteyi bozamaz.
    public static func duzelt(_ metin: String, zamanAsimi: TimeInterval = 20) async -> String {
        guard !metin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return metin }

        // Örnekler ayrı user/assistant çiftleri olarak gider; talimat içine gömülen
        // örnekler küçük modellerde çıktıya sızıyordu (2026-07-03).
        var mesajlar: [[String: String]] = [["role": "system", "content": Ayarlar.llmSistemPromptu]]
        for ornek in Ayarlar.llmOrnekler {
            mesajlar.append(["role": "user", "content": ornek.girdi])
            mesajlar.append(["role": "assistant", "content": ornek.cikti])
        }
        mesajlar.append(["role": "user", "content": metin])

        let govde: [String: Any] = [
            "model": Ayarlar.ollamaModel,
            "messages": mesajlar,
            "stream": false,
            "keep_alive": Ayarlar.ollamaBellekteTut,
            "options": ["temperature": 0.1, "num_predict": Ayarlar.ollamaTokenSiniri],
        ]

        var istek = URLRequest(url: Ayarlar.ollamaURL.appendingPathComponent("api/chat"))
        istek.httpMethod = "POST"
        istek.setValue("application/json", forHTTPHeaderField: "Content-Type")
        istek.timeoutInterval = zamanAsimi
        istek.httpBody = try? JSONSerialization.data(withJSONObject: govde)

        guard let (veri, _) = try? await URLSession.shared.data(for: istek),
              let kok = try? JSONSerialization.jsonObject(with: veri) as? [String: Any],
              let mesaj = kok["message"] as? [String: Any],
              let icerik = mesaj["content"] as? String else { return metin }

        let cikti = dusunmeyiAyikla(icerik)
        return cikti.isEmpty ? metin : cikti
    }
}
