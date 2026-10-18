// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EditPadKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "EditPadKit", targets: ["EditPadKit"]),
    ],
    targets: [
        .target(name: "EditPadKit"),
        .testTarget(name: "EditPadKitTests", dependencies: ["EditPadKit"]),
    ]
)
