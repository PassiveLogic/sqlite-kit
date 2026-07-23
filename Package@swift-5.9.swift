// swift-tools-version:5.9
import PackageDescription

let allPlatforms: [Platform] = [.macOS, .macCatalyst, .iOS, .tvOS, .watchOS, .visionOS, .driverKit, .linux, .windows, .android, .wasi, .openbsd]
let nonWASIPlatforms: [Platform] = allPlatforms.filter { $0 != .wasi }

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
        // WASM: upstream swift-nio + standalone nio-async-runtime; wasm-safe vapor forks.
        // Pin to tagged fork releases once available.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.89.0"),
        .package(url: "https://github.com/PassiveLogic/nio-async-runtime.git", from: "1.0.0"),
        .package(url: "https://github.com/PassiveLogic/sqlite-nio.git", from: "1.9.0"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.33.1"),
        .package(url: "https://github.com/PassiveLogic/async-kit.git", from: "1.19.0"),
    ],
    targets: [
        .target(
            name: "SQLiteKit",
            dependencies: [
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOAsyncRuntime", package: "nio-async-runtime", condition: .when(platforms: [.wasi])),
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
