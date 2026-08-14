// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Babos",
    platforms: [.macOS(.v14)],   // @Observable 需要 macOS 14 以上
    targets: [
        .executableTarget(name: "Babos", path: "Sources/Babos")
    ]
)
