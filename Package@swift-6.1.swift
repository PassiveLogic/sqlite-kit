// swift-tools-version:6.1
import PackageDescription

// Trait-aware manifest (SE-0450). Modern toolchains select this over Package.swift / Package@swift-5.9.swift.
//
//  - `SwiftNIO` (default): the existing SwiftNIO/EventLoopFuture stack — unchanged behavior, incl. the
//    regular-WASI NIOAsyncRuntime substitution.
//  - `EmbeddedWASI`: a NIO-free, Swift-Concurrency stack for Embedded Swift / WASI. Enable it *instead
//    of* the defaults, e.g.:
//        swift build --traits EmbeddedWASI --swift-sdk <embedded-wasm-sdk>
//    This turns `SwiftNIO` off, which drops swift-nio AND async-kit (no connection pooling on the
//    in-memory embedded path) and propagates `EmbeddedWASI` to sqlite-nio and sql-kit.
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
    traits: [
        .trait(name: "SwiftNIO", description: "Default backend built on SwiftNIO (EventLoopFuture)."),
        .trait(
            name: "EmbeddedWASI",
            description: "NIO-free, Swift-Concurrency stack for Embedded Swift / WASI. Enable instead of the defaults; drops swift-nio and async-kit."
        ),
        .default(enabledTraits: ["SwiftNIO"]),
    ],
    dependencies: [
        .package(path: "../swift-nio"),
        .package(
            path: "../sqlite-nio",
            traits: [.defaults, .trait(name: "EmbeddedWASI", condition: .when(traits: ["EmbeddedWASI"]))]
        ),
        .package(
            path: "../sql-kit",
            traits: [.defaults, .trait(name: "EmbeddedWASI", condition: .when(traits: ["EmbeddedWASI"]))]
        ),
        .package(path: "../async-kit"),
    ],
    targets: [
        .target(
            name: "SQLiteKit",
            dependencies: [
                // SwiftNIO backend (default). Dropped entirely under EmbeddedWASI.
                .product(name: "NIOCore", package: "swift-nio", condition: .when(traits: ["SwiftNIO"])),
                .product(name: "NIOFoundationCompat", package: "swift-nio", condition: .when(platforms: nonWASIPlatforms, traits: ["SwiftNIO"])),
                .product(name: "NIOAsyncRuntime", package: "swift-nio", condition: .when(platforms: wasiPlatform, traits: ["SwiftNIO"])),
                .product(name: "NIOPosix", package: "swift-nio", condition: .when(platforms: nonWASIPlatforms, traits: ["SwiftNIO"])),
                // async-kit provides ConnectionPoolSource; the in-memory embedded path needs no pool.
                .product(name: "AsyncKit", package: "async-kit", condition: .when(traits: ["SwiftNIO"])),
                // These ship both backends (selected by their own EmbeddedWASI trait, propagated above).
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
