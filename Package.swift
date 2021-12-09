// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "BackendProject",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        // framework para servidores web
        .package(url: "https://github.com/vapor/vapor.git", from: "4.53.0"),
        // parser de HTML para usar no web scraping
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.3")
    ],
    targets: [
        // o servidor propriamente
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .target(name: "RapidFuzz")
            ],
            cSettings: Settings.c,
            cxxSettings: Settings.cxx,
            swiftSettings: Settings.swift
        ),
        // executável que inicializa o servidor
        .executableTarget(
            name: "Run",
            dependencies: [
                .target(name: "App")
            ],
            cSettings: Settings.c,
            cxxSettings: Settings.cxx,
            swiftSettings: Settings.swift
        ),
        // integração com RapidFuzz
        .target(
            name: "RapidFuzz",
            exclude: ["rapidfuzz-cpp"],
            cSettings: Settings.c,
            cxxSettings: Settings.cxx + [
                .headerSearchPath("rapidfuzz-cpp"),
                // Modo de cálculo do score, usando uma das classes em
                // https://github.com/maxbachmann/rapidfuzz-cpp#readme
                .define("RATIO_TYPE", to: "CachedPartialRatio")
            ],
            swiftSettings: Settings.swift
        ),
        // testes do servidor
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor")
            ],
            // habilita warnings e erros de C/C++
            cSettings: Settings.c + [.unsafeFlags(Settings.warnings)],
            cxxSettings: Settings.cxx + [.unsafeFlags(Settings.warnings)],
            swiftSettings: Settings.swift
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu2x,
    cxxLanguageStandard: .gnucxx20
)

/// Configurações padrões de cada linguagem.
private enum Settings {
    static let swift: [SwiftSetting] = [
        // Detalhes em https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production
        .unsafeFlags(
            [
                "-Ounchecked", "-remove-runtime-asserts",
                "-cross-module-optimization", "-whole-module-optimization"
            ],
            .when(configuration: .release)
        ),
        .unsafeFlags(["-Onone", "-g"], .when(configuration: .debug)),
        // problemas de compilação de código async no linux
        .unsafeFlags(["-Xfrontend", "-validate-tbd-against-ir=none"], .when(platforms: [.linux], configuration: .debug))
    ]

    static let cxx: [CXXSetting] = [
        // flags básicas de depuração e otimização
        .unsafeFlags(debugFlags, .when(configuration: .debug)),
        .define("NDEBUG", .when(configuration: .release)),
        .unsafeFlags(optimizationFlags, .when(configuration: .release))
    ]

    // swiftlint:disable identifier_name
    static let c: [CSetting] = [
        // flags básicas de depuração e otimização
        .unsafeFlags(debugFlags, .when(configuration: .debug)),
        .define("NDEBUG", .when(configuration: .release)),
        .unsafeFlags(optimizationFlags, .when(configuration: .release))
    ]

    static let optimizationFlags = [
        "-O3", "-march=native", "-mtune=native", "-pipe",
        "-fno-plt", "-fno-exceptions",
        "-ffast-math", "-fshort-enums"
    ]
    static let debugFlags = ["-O1", "-ggdb3"]
    // warnings não são ativados por padrão por conta das bibliotecas NIO
    static let warnings = ["-Wall", "-Wextra", "-Wpedantic"]
}
