// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SQLGarden",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SQLGarden", targets: ["SQLGarden"])],
    targets: [
        .target(name: "StudioCore"),
        .target(name: "SQLBridge", publicHeadersPath: "include", linkerSettings: [
            .linkedLibrary("dl", .when(platforms: [.linux]))
        ]),
        .executableTarget(name: "SQLGarden", dependencies: ["StudioCore", "SQLBridge"]),
        .testTarget(name: "StudioCoreTests", dependencies: ["StudioCore"])
    ]
)
