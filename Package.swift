// swift-tools-version:6.0
import Foundation
import PackageDescription

// ── Whisper motoru ───────────────────────────────────────────────────────────
// WhisperKit (CoreML) kullanılıyor, whisper.cpp değil. Gerekçe: whisper.cpp
// SwiftPM desteğini bıraktı — son manifest v1.7.4'te ve o da sistem kütüphanesi
// bekliyor (brew ile ayrıca kurulum gerektirir); güncel sürümlerde manifest hiç
// yok, hazır xcframework de yayınlanmıyor. WhisperKit gerçek bir SwiftPM paketi,
// Apple Silicon'da Neural Engine kullanıyor. Bkz. brain/Kararlar 2026-09-02.
//
// ── Dağıtım modu (LISTENDER_DIST=1) ──────────────────────────────────────────
// Yalnız TEST bağımlılığını atlar (swift-testing kaynaktan derleniyor, bkz.
// Droper). WhisperKit çalışma zamanı bağımlılığı olduğu için her modda çekilir.

let dagitimDerlemesi = ProcessInfo.processInfo.environment["LISTENDER_DIST"] != nil

let cltTestingLib = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

var dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
]

var targets: [Target] = [
    .target(
        name: "ListenderKit",
        dependencies: [.product(name: "WhisperKit", package: "WhisperKit")],
        swiftSettings: [.swiftLanguageMode(.v5)]),
    .executableTarget(
        name: "Listender",
        dependencies: ["ListenderKit"],
        swiftSettings: [.swiftLanguageMode(.v5)]),
]

if !dagitimDerlemesi {
    dependencies.append(
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.3.1"))
    targets.append(
        .testTarget(
            name: "ListenderKitTests",
            dependencies: [
                "ListenderKit",
                .product(name: "Testing", package: "swift-testing"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .unsafeFlags([
                    "-L", cltTestingLib,
                    "-Xlinker", "-rpath", "-Xlinker", cltTestingLib,
                ])
            ]))
}

let package = Package(
    name: "Listender",
    platforms: [.macOS(.v14)],
    dependencies: dependencies,
    targets: targets
)
