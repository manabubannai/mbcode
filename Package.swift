// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "mbcode",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "ZenKit",
            path: "Sources/ZenKit"
        ),
        .executableTarget(
            name: "mbcode",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm"), "ZenKit"],
            path: "Sources/mbcode"
        ),
        .executableTarget(
            name: "zenlauncher",
            dependencies: ["ZenKit"],
            path: "Sources/zenlauncher"
        )
    ]
)
