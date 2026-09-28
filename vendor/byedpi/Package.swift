// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "byedpi",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(name: "ByeDpiEngine", targets: ["ByeDpiEngine"])
    ],
    targets: [
        .target(
            name: "ByeDpiEngine",
            path: "upstream",
            sources: ["library_main.c", "conev.c", "proxy.c", "desync.c", "mpool.c", "extend.c", "packets.c", "engine.c"],
            publicHeadersPath: "include",
            cSettings: [
                .define("BYEDPI_LIBRARY"),
                .headerSearchPath(".")
            ]
        ),
        .testTarget(name: "ByeDpiEngineTests", dependencies: ["ByeDpiEngine"])
    ]
)
