// swift-tools-version:5.4
import PackageDescription

private let swiftSettings = [
    // Detalhes em https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production
    SwiftSetting.unsafeFlags([
        "-cross-module-optimization",
        "-whole-module-optimization",
    ], .when(configuration: .release))
]

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
        // o servidor propriamente
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .target(name: "Services")
            ],
            swiftSettings: swiftSettings
        ),
        // executável que inicializa o servidor
        .executableTarget(
            name: "Run",
            dependencies: [.target(name: "App")],
            swiftSettings: swiftSettings
        ),
        // funções e tipos utilitários
        .target(
            name: "Services",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            swiftSettings: swiftSettings
        ),
        // testes do servidor
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ],
    swiftLanguageVersions: [.v5]
)
