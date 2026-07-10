// swift-tools-version:6.1
import PackageDescription

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
        .default(enabledTraits: ["NIO"]),
        .trait(
            name: "NIO",
            description: "Default backend: SwiftNIO + AsyncKit (EventLoopFuture surface and the connection-pool source)."
        ),
        .trait(
            name: "NativeConcurrency",
            description: "NIO-free build on Swift concurrency: no AsyncKit connection pool, async-only query surface over sqlite-nio's NativeConcurrency driver. Build with `--traits NativeConcurrency` (replaces the default NIO trait)."
        ),
        .trait(
            name: "Freestanding",
            description: "Embedded/freestanding flavor (implies NativeConcurrency). No additional source effect in this package beyond NativeConcurrency; declared so a root's `--traits Freestanding` configuration names a known trait when this package is wired by path.",
            enabledTraits: ["NativeConcurrency"]
        ),
    ],
    dependencies: [
        // TODO: SM: Update swift-nio version once NIOAsyncRuntime is available from swift-nio
        // .package(url: "https://github.com/apple/swift-nio.git", from: "2.89.0"),
        .package(url: "https://github.com/PassiveLogic/swift-nio.git", branch: "feat/khasmPAL-2026"),

        // Local embedded-ported clones (see /Users/scottm/git/c34/EMBEDDED_WASM_NOTES.md),
        // branched from the same revisions khasm's Package.resolved pins, so regular
        // (non-embedded) builds see identical sources.
        .package(path: "../sqlite-nio", traits: [
            .trait(name: "default", condition: .when(traits: ["NIO"])),
            .trait(name: "NativeConcurrency", condition: .when(traits: ["NativeConcurrency"])),
        ]),
        .package(path: "../sql-kit", traits: [
            .trait(name: "default", condition: .when(traits: ["NIO"])),
            .trait(name: "NativeConcurrency", condition: .when(traits: ["NativeConcurrency"])),
        ]),
//        .package(url: "https://github.com/vapor/async-kit.git", from: "1.19.0"),
        .package(url: "https://github.com/PassiveLogic/async-kit.git", branch: "feat/khasmPAL-2026"),
    ],
    targets: [
        .target(
            name: "SQLiteKit",
            dependencies: [
                .product(name: "SQLiteNIO", package: "sqlite-nio"),
                .product(name: "SQLKit", package: "sql-kit"),
                // The SwiftNIO/AsyncKit stack rides the default `NIO` trait; with
                // `NativeConcurrency` enabled instead, SQLiteKit is NIO-free (no pool),
                // gated in source with `#if NativeConcurrency`.
                .product(name: "NIOFoundationCompat", package: "swift-nio", condition: .when(traits: ["NIO"])),
                .product(name: "NIOAsyncRuntime", package: "swift-nio", condition: .when(platforms: [.wasi], traits: ["NIO"])),
                .product(name: "NIOPosix", package: "swift-nio", condition: .when(traits: ["NIO"])),
                .product(name: "AsyncKit", package: "async-kit", condition: .when(traits: ["NIO"])),
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
    // This manifest raises the tools-version to 6.1 (for package traits); the package sources
    // stay in the Swift 5 language mode of the earlier manifests.
    .swiftLanguageMode(.v5),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("ForwardTrailingClosures"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency=complete"),
] }
