// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Nhip",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Nhip", targets: ["Nhip"]), .executable(name: "NhipChecks", targets: ["NhipChecks"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "NhipCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "Nhip", dependencies: ["NhipCore"]),
        .executableTarget(name: "NhipChecks", dependencies: ["NhipCore"], path: "Tests/NhipCoreTests")
    ]
)
