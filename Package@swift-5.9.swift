// swift-tools-version:5.9
import PackageDescription

/// `.when(platforms:)` can only include, never exclude, so excluding WASI means listing everything else.
/// This list matches the [supported platforms on the Swift 5.9 release of SPM](https://github.com/swiftlang/swift-package-manager/blob/release/5.9/Sources/PackageDescription/SupportedPlatforms.swift).
/// Don't add new platforms here unless raising the swift-tools-version of this manifest.
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
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/vapor/sqlite-nio.git", from: "1.9.0"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.29.3"),
        .package(url: "https://github.com/vapor/async-kit.git", from: "1.19.0"),
    ],
    targets: [
        .target(
            name: "SQLiteKit",
            dependencies: [
                // Target dependency conditions are evaluated per platform; on WASI these two
                // products are not linked. AsyncKit's pool rides NIOPosix, which needs the POSIX
                // sockets and threads WASI preview 1 lacks, and sqlite-nio's WASI flavor is
                // SwiftNIO-free, so NIOFoundationCompat would have nothing to bridge and a linked
                // NIOCore would flip the `#if canImport(NIOCore)` gates against a SQLiteNIO with no
                // event loops. SQLiteKit then compiles without the connection pool and without the
                // EventLoopFuture surface (see the `#if canImport(...)` gates in Sources/).
                .product(name: "NIOFoundationCompat", package: "swift-nio", condition: .when(platforms: nonWASIPlatforms)),
                .product(name: "AsyncKit", package: "async-kit", condition: .when(platforms: nonWASIPlatforms)),
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
