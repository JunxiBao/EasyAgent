// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EasyAgent",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "EasyAgent", targets: ["EasyAgent"])
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.1.2")
    ],
    targets: [
        .executableTarget(
            name: "EasyAgent",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Highlightr", package: "Highlightr")
            ],
            path: "Sources/EasyAgent"
        )
    ]
)
