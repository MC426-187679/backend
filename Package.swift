// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "BackendProject",
    platforms: [
       .macOS(.v10_15)
    ],
    dependencies: [
        // biblioteca para Logging, usada pelo Vapor
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        // framework para servidores web
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "Services",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .target(name: "Services")
            ],
            swiftSettings: [
                // Detalhes em https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .target(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ],
    swiftLanguageVersions: [.v5]
)
