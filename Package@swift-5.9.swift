// swift-tools-version:5.9
import PackageDescription

let nonWASIPlatforms: [Platform] = [.macOS, .macCatalyst, .iOS, .tvOS, .watchOS, .visionOS, .driverKit, .linux, .windows, .android, .openbsd]
let wasiPlatform: [Platform] = [.wasi]

let package = Package(
    name: "sqlite-kit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(name: "SQLiteKit", targets: ["SQLiteKit"]),
    ],
    dependencies: [
        // Local clones for the embedded-wasm port (see /Users/scottm/git/c34/EMBEDDED_WASM_NOTES.md)
        .package(path: "../swift-nio"),
        .package(path: "../sqlite-nio"),
        .package(path: "../sql-kit"),
        .package(path: "../async-kit"),
    ],
    targets: [
        .target(
            name: "SQLiteKit",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                // NIOFoundationCompat pulls in Foundation; unavailable on the embedded WASI target.
                .product(name: "NIOFoundationCompat", package: "swift-nio", condition: .when(platforms: nonWASIPlatforms)),
                // On WASI use the async-await event loop; elsewhere NIOPosix.
                .product(name: "NIOAsyncRuntime", package: "swift-nio", condition: .when(platforms: wasiPlatform)),
                .product(name: "NIOPosix", package: "swift-nio", condition: .when(platforms: nonWASIPlatforms)),
                .product(name: "AsyncKit", package: "async-kit"),
                .product(name: "SQLiteNIO", package: "sqlite-nio"),
                .product(name: "SQLKit", package: "sql-kit"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SQLiteKitTests",
            dependencies: [
                .product(name: "SQLKitBenchmark", package: "sql-kit"),
                .target(name: "SQLiteKit"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("ForwardTrailingClosures"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency=complete"),
] }
