// swift-tools-version:5.9
import class Foundation.ProcessInfo
import PackageDescription

/// `.when(platforms:)` can only include, never exclude, so excluding WASI means listing everything else.
/// This list matches the [supported platforms on the Swift 5.9 release of SPM](https://github.com/swiftlang/swift-package-manager/blob/release/5.9/Sources/PackageDescription/SupportedPlatforms.swift).
/// Don't add new platforms here unless raising the swift-tools-version of this manifest.
let allPlatforms: [Platform] = [.macOS, .macCatalyst, .iOS, .tvOS, .watchOS, .visionOS, .driverKit, .linux, .windows, .android, .wasi, .openbsd]
let nonWASIPlatforms: [Platform] = allPlatforms.filter { $0 != .wasi }
let wasiPlatform: [Platform] = [.wasi]

// ┌────────────────────────────────────────────────────────────────────────────┐
// │ DOWNSTREAM-ONLY — `integration/khasm-embedded`. NOT FOR UPSTREAM.             │
// │ Must never be cherry-picked onto feat/wasi-nio-free or feat/embedded-support. │
// └────────────────────────────────────────────────────────────────────────────┘
//
// Upstream elides SwiftNIO and AsyncKit for ALL of WASI, which deletes
// ``SQLiteConnectionSource`` (and therefore any connection pool) there. khasm's REGULAR
// wasm flavor cannot accept that: quantum-sqlite-driver builds its database on
// `EventLoopConnectionPool<SQLiteConnectionSource>` + `NIOThreadPool` ungated. Only
// khasm's Embedded/Freestanding flavor (KHASM_EMBEDDED=1) wants the upstream behavior,
// so the WASI elision is scoped to that flavor; every other build keeps the full
// surface, which makes the upstream `#if canImport(...)` gates inert.
let khasmEmbedded = ProcessInfo.processInfo.environment["KHASM_EMBEDDED"] == "1"
let nioPlatforms: [Platform] = khasmEmbedded ? nonWASIPlatforms : allPlatforms

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
        // DOWNSTREAM-ONLY: the PassiveLogic forks of swift-nio and async-kit rather than the
        // upstream URLs. khasm's root manifest pins both identities to those forks on a
        // branch; when this manifest named the upstream URLs, SwiftPM canonicalized the
        // identities onto them while keeping the root's branch requirement and then failed
        // with `unable to read tree` on the fork-only revisions. The fork is also where
        // NIOAsyncRuntime (the only wasm-capable EventLoopGroup) lives.
        .package(url: "https://github.com/PassiveLogic/swift-nio.git", branch: "feat/khasmPAL-2026"),
        .package(url: "https://github.com/PassiveLogic/async-kit.git", branch: "feat/khasmPAL-2026"),
        // sqlite-nio and sql-kit keep their upstream URLs: khasm's ROOT manifest path-wires
        // `../sqlite-nio` and `../sql-kit`, and a root path declaration wins those
        // identities graph-wide.
        .package(url: "https://github.com/vapor/sqlite-nio.git", from: "1.9.0"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.29.3"),
    ],
    targets: [
        .target(
            name: "SQLiteKit",
            dependencies: [
                // Target dependency conditions are evaluated per platform. Where these are not
                // linked, AsyncKit's pool would have ridden NIOPosix, which needs the POSIX
                // sockets and threads WASI preview 1 lacks, and NIOFoundationCompat would have no
                // `ByteBuffer` to bridge, so SQLiteKit compiles without the connection pool and
                // without the EventLoopFuture surface (see the `#if canImport(...)` gates in
                // Sources/).
                // DOWNSTREAM-ONLY: `nioPlatforms` excludes WASI only under KHASM_EMBEDDED=1
                // (see the note at the top of this file). NIOPosix is listed explicitly because
                // SQLiteConnectionSource imports it directly; on WASI it resolves as a partial
                // module, so NIOAsyncRuntime supplies the thread pool there instead.
                .product(name: "NIOFoundationCompat", package: "swift-nio", condition: .when(platforms: nioPlatforms)),
                .product(name: "NIOPosix", package: "swift-nio", condition: .when(platforms: nioPlatforms)),
                .product(name: "AsyncKit", package: "async-kit", condition: .when(platforms: nioPlatforms)),
                .product(name: "SQLiteNIO", package: "sqlite-nio"),
                .product(name: "SQLKit", package: "sql-kit"),
            ] + (khasmEmbedded ? [] : [
                .product(name: "NIOAsyncRuntime", package: "swift-nio", condition: .when(platforms: wasiPlatform)),
            ] as [Target.Dependency]),
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
