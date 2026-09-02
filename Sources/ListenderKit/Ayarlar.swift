import Foundation

/// Merkezi ayarlar ve sabitler. Python sürümündeki `config.py`'nin karşılığı;
/// ölçülmüş değerler (eşikler, model tercihi, prompt) birebir korundu.
public enum Ayarlar {

    // MARK: Model

    /// WhisperKit model adı. `openai_whisper-large-v3-v20240930_turbo`, Python
    /// sürümünün kullandığı ggml `large-v3-turbo` modelinin CoreML karşılığı.
    public static let modelAdi = "openai_whisper-large-v3-v20240930_turbo"

    /// Modellerin indirileceği kök (~1,5 GB, bir kez). WhisperKit bunun altına
    /// kendisi `models/<depo>/<model>` ağacını kuruyor, o yüzden buraya ayrıca
    /// "models" eklenmiyor. Varsayılanı ~/Documents altı; uygulama verisi
    /// Documents'ı kirletmesin diye taşındı.
    public static var modelKlasoru: URL { destekKlasoru }

    public static var destekKlasoru: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Listender", isDirectory: true)
    }

    // MARK: Ses

    public static let ornekleme: Double = 16_000   // whisper'ın beklediği örnekleme
    public static let preRollSaniye: Double = 0.5  // tuşa basmadan önceki ses de girsin
    public static let enUzunKayitSaniye: Double = 120  // bellek koruması
    public static let enKisaKayitSaniye: Double = 0.5  // altındaki basmalar atlanır

    /// Kablosuz mikrofon çok kısık gelebiliyor (canlı ölçüm: konuşma RMS ~0,009).
    /// Transkript öncesi tepe normalizasyonu sesi whisper'ın rahat çözdüğü yere çeker.
    public static let normalizeTepe: Float = 0.95
    /// Altındaki "ses yok" sayılır, whisper'a hiç gitmez (halüsinasyon önlemi).
    public static let sessizlikRMS: Float = 0.0002

    // MARK: Whisper

    public static let dil = "tr"   // sabit, otomatik algılama yok

    // MARK: Temizlik

    /// Bağımsız token olarak her yerde silinen dolgular.
    public static let dolguTokenlari = ["eee", "ee", "ıı", "hı", "hıı", "ııı"]
    /// Yalnızca cümle başında veya ardışık tekrarda temizlenen yumuşak dolgular.
    public static let yumusakDolgular = ["yani", "hani", "şey", "işte", "falan"]
    /// Whisper'ın boş/sessiz seste ürettiği bilinen halüsinasyonlar.
    public static let halusinasyonKaliplari = [
        "altyazı m.k.",
        "altyazı mk",
        "abone ol",
        "izlediğiniz için teşekkür",
        "teşekkür ederim",
    ]

    // MARK: Ollama (opsiyonel LLM temizliği)

    // Model tarihi (bkz. brain/Kararlar 2026-07-03):
    // - qwen3:4b — thinking kapatılamıyor, 60+ sn, elendi.
    // - qwen2.5:3b-instruct — hızlı ama anlamı bozuyor (prompt sızıntısı, Çince
    //   karakter, kişi kayması), elendi.
    // - qwen3:4b-instruct — en iyisi, ~0,6 sn. Yine de kişi kayması yapabiliyor
    //   ("verdim" -> "verildi"), o yüzden VARSAYILAN KAPALI.
    public static let ollamaURL = URL(string: "http://127.0.0.1:11434")!
    public static let ollamaModel = "qwen3:4b-instruct"
    /// Finder'dan açılan .app'in PATH'inde /opt/homebrew/bin olmaz.
    public static let ollamaBinaryYollari = [
        "/opt/homebrew/bin/ollama",
        "/usr/local/bin/ollama",
        "/Applications/Ollama.app/Contents/Resources/ollama",
    ]
    public static let ollamaIndirmeURL = URL(string: "https://ollama.com/download")!
    public static let ollamaBellekteTut = "30m"
    public static let ollamaTokenSiniri = 256
    public static let llmVarsayilanAcik = false

    public static let llmSistemPromptu = """
        Türkçe dikte metnini düzelt: dolgu kelimelerini (eee, ıı, yani, hani, şey, \
        işte, falan) sil, noktalama ve büyük harfleri düzelt. Kelimeleri, fiil \
        çekimlerini ve zamanı AYNEN koru; kelime ekleme, çıkarma, eş anlamlısıyla \
        değiştirme. Yabancı veya bilmediğin kelimeleri (marka, uygulama adı) aynen \
        bırak. Sadece düzeltilmiş metni yaz.
        """

    /// Örnekler ayrı user/assistant mesajları olarak gönderilir — talimat içine
    /// gömülen örnekler küçük modellerde çıktıya sızıyordu (2026-07-03'te test edildi).
    public static let llmOrnekler: [(girdi: String, cikti: String)] = [
        ("eee bugün müşteriyle görüştük yani sipariş onaylandı",
         "Bugün müşteriyle görüştük, sipariş onaylandı."),
        ("yarın ııı saat üçte şey toplantı var işte",
         "Yarın saat üçte toplantı var."),
        ("fiyat listesini ııı dün akşam güncelledim işte",
         "Fiyat listesini dün akşam güncelledim."),
        ("bu ürünün fiyatını hani beş yüz lira yapalım mı",
         "Bu ürünün fiyatını beş yüz lira yapalım mı?"),
    ]

    // MARK: Enjeksiyon

    /// Cmd-V sonrası eski panoyu geri yüklemeden önce beklenecek süre.
    public static let panoGeriYuklemeGecikmesi: Double = 0.3

    // MARK: Log

    /// Teşhis logu. Python sürümü /tmp/listender.log kullanıyordu; dikte metni
    /// herkese açık /tmp'ye yazılmasın diye kullanıcı log klasörüne alındı
    /// (denetimde gizlilik bulgusu olarak işaretlenmişti).
    public static var logDosyasi: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Listender/listender.log")
    }
}
