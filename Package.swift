// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "not31",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "not31", targets: ["not31"])
    ],
    targets: [
        .executableTarget(
            name: "not31",
            path: "Sources/not31"
        )
    ]
)
