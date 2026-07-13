// swift-tools-version:5.9
// 3D素材サムネ台帳 (AssetLedger) — macOS 14+
// Xcodeで開く: このPackage.swiftをダブルクリック → My Mac向けにRun
// CLIで実行:   cd asset-ledger && swift run
import PackageDescription

let package = Package(
    name: "AssetLedger",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AssetLedger",
            path: "Sources/AssetLedger"
        )
    ]
)
