// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LastLightCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "LastLightCore", targets: ["LastLightCore"]),
        .executable(name: "lastlight-sim", targets: ["lastlight-sim"]),
    ],
    targets: [
        .target(name: "LastLightCore"),
        .executableTarget(name: "lastlight-sim", dependencies: ["LastLightCore"]),
        .testTarget(name: "LastLightCoreTests", dependencies: ["LastLightCore"]),
    ]
)
