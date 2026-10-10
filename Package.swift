// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConnectFour",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ConnectFour", targets: ["ConnectFour"])],
    targets: [
        .target(name: "ConnectFourCore"),
        .executableTarget(name: "ConnectFour", dependencies: ["ConnectFourCore"]),
        .testTarget(name: "ConnectFourCoreTests", dependencies: ["ConnectFourCore"])
    ]
)
