// swift-tools-version:5.9
import class Foundation.ProcessInfo
import PackageDescription

// Embedded-wasm port (see /Users/scottm/git/c34/khasm/EMBEDDED_PORT_PLAN.md): with
// KHASM_EMBEDDED=1 the SwiftNIO stack and AsyncKit's connection pool are dropped — the
// Embedded build uses sqlite-nio's NIO-free Swift-Concurrency driver directly, gated in
// source with `#if hasFeature(Embedded)` (not available in manifests, hence the env var,
// matching khasm's own manifest gating). Regular builds — including regular WASI via
// NIOAsyncRuntime — keep the NIO stack exactly as on the feat/khasmPAL-2026 base.
let khasmEmbedded = ProcessInfo.processInfo.environment["KHASM_EMBEDDED"] == "1"

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
        // swift-nio / async-kit stay on the PassiveLogic fork URLs (feat/khasmPAL-2026, as on
        // the base branch) rather than local clones: the local swift-nio clone carries the
        // vestigial Option-1/2 embedded-NIO commits whose os(WASI) gates would change
        // regular-WASI NIO behavior, and transitive *path* deps override URL declarations by
        // identity in a consuming root graph (khasm). Under KHASM_EMBEDDED=1 both are dropped.
        .package(url: "https://github.com/PassiveLogic/swift-nio.git", branch: "feat/khasmPAL-2026"),
        .package(url: "https://github.com/PassiveLogic/async-kit.git", branch: "feat/khasmPAL-2026"),
        // Local embedded-ported clones (see /Users/scottm/git/c34/EMBEDDED_WASM_NOTES.md),
        // branched from the same revisions khasm's Package.resolved pins, so regular
        // (non-embedded) builds see identical sources.
        .package(path: "../sqlite-nio"),
        .package(path: "../sql-kit"),
    ],
    targets: [
        .target(
            name: "SQLiteKit",
            dependencies: [
                .product(name: "SQLiteNIO", package: "sqlite-nio"),
                .product(name: "SQLKit", package: "sql-kit"),
            ] + (khasmEmbedded ? [] : [
                // Dropped on the Embedded build (KHASM_EMBEDDED=1, see note at the top).
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOAsyncRuntime", package: "swift-nio", condition: .when(platforms: [.wasi])),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "AsyncKit", package: "async-kit"),
            ]),
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
