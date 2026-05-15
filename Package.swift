// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlowInk",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FlowInk", targets: ["FlowInk"])
    ],
    targets: [
        .executableTarget(
            name: "FlowInk"
        )
    ]
)
