import Foundation
import Vapor
import SwiftSoup

/// Algum dado que é recuperado da internet, em geral através de parsing HTML.
protocol WebScrapable {
    /// Nome do arquivo usado para fazer caching dos resultados.
    ///
    /// Padrão: nome do tipo.
    static var cacheFile: String { @inlinable get }

    /// Saída do script de scraping. Normalmente uma coleção de `Self`.
    associatedtype WebScrapingOutput: Codable

    /// Faz o scraping do tipo de forma assíncrona usando o `WebScraper` da aplicação.
    ///
    /// - Parameter scraper: ``WebScraper`` usado para fazer requisições.
    /// - Returns: Conteúdo parseado do scraping.
    @inlinable
    static func scrape(with scraper: WebScraper) async throws -> WebScrapingOutput

    /// Retorna a contagem de elementos da saída. Usada para depuração e logging.
    @inlinable
    static func size(of output: WebScrapingOutput) -> Int
}

extension WebScrapable {
    @inlinable
    static var cacheFile: String {
        "\(Self.self)"
    }
}

extension WebScrapable where WebScrapingOutput: Collection {
    @inlinable
    static func size(of output: WebScrapingOutput) -> Int {
        output.count
    }
}

extension Application {
    /// WebScraper padrão da aplicação.
    var webScraper: WebScraper {
        WebScraper(app: self)
    }
}

/// Serviço resposável por fazer o scraping dos dados, fazendo as requisições necessárias e o caching dos resultados.
struct WebScraper {
    // MARK: - Configuração

    /// Configuração global do `WebScraper`.
    struct Configuration {
        /// Avisa se a aplicação está usando versões mais novas do HTTP.
        ///
        /// Vários sites mais antigos tem problema em tratar corretamente requisições em HTTP/2.
        public var warnAboutHttpVersion = true
        /// Nome do diretório usado para caching em `Resources`. (padrão: "Cache")
        public var cacheDirectory = "Cache"
        /// Se o `WebScraper` deve fazer e usar caching dos resultados de scraping.
        public var useCaching = true

        /// Singleton que mantém a config global.
        public static var global = Configuration()
    }

    /// Controle global de warning, para evitar que ele seja lançado múltiplas vezes.
    private actor HTTPVersionWarning {
        /// Versão HTTP usada nas requisições com o `client`.
        typealias HTTPVersion = HTTPClient.Configuration.HTTPVersion

        /// Se o warning já foi ativado.
        private var alreadyWarned = false

        /// Se o warning deveria ser feito, considerando a config do app.
        private func shouldWarn(for version: HTTPVersion) -> Bool {
            !self.alreadyWarned
            && Configuration.global.warnAboutHttpVersion
            && "\(version)" != "\(HTTPVersion.http1Only)"
        }

        /// Faz o warning com a aplicação, se ainda não foi feito.
        func warnIfNeeded(on app: Application) {
            let version = app.http.client.configuration.httpVersion

            if self.shouldWarn(for: version) {
                app.logger.warning(
                    """
                    HTTPClient may be using another HTTP version for requests. This could result in
                    remoteConnectionClosed for site applications. More details on
                    https://github.com/swift-server/async-http-client/issues/488.
                    """,
                    metadata: [
                        "service": "\(Self.self)",
                        "http-version-config": "\(version)"
                    ]
                )
                self.alreadyWarned = true
            }
        }
    }

    /// Controle global de warning, para evitar que ele seja lançado múltiplas vezes.
    private static var httpVersionWarning = HTTPVersionWarning()

    /// A aplicação que está usando o `WebScraper`.
    private let app: Application
    /// Logger da aplciação, exportado para uso durante o scraping.
    @inlinable
    var logger: Logger {
        self.app.logger
    }
    /// Configuração global do `WebScraper`.
    @inlinable
    var configuration: Configuration {
        get { Configuration.global }
        nonmutating set { Configuration.global = newValue }
    }

    /// Incializa `WebScraper` para a aplicação.
    fileprivate init(app: Application) {
        self.app = app
    }
}

extension WebScraper {
    // MARK: - Requisições HTTP

    /// Acesso do client da aplicação, mas ativa o warning se necessário.
    private var client: Client {
        get async {
            await Self.httpVersionWarning.warnIfNeeded(on: self.app)
            return self.app.client
        }
    }

    /// Faz a requisição e decodificação de um conteúdo da internet.
    @inlinable
    func get<Content: Decodable>(
        _ type: Content.Type = Content.self,
        from url: String,
        using decoder: ContentDecoder? = nil
    ) async throws -> Content {

        let response = try await self.client.get(URI(string: url))
        if let decoder = decoder {
            return try response.content.decode(type, using: decoder)
        } else {
            return try response.content.decode(type)
        }
    }

    /// Faz a requisição e o parsing de uma página HTML.
    @inlinable
    func getHTML(from url: String) async throws -> Document {
        let text: String = try await self.get(from: url, using: PlaintextDecoder())
        let document = try SwiftSoup.parse(text, url)
        return document
    }
}

extension WebScraper {
    // MARK: - Scraping e caching

    /// Faz o scraping do conteúdo, se necessário. Sempre prefere usar o caching para carregar os dados.
    @inlinable
    func scrape<Content: WebScrapable>(_ type: Content.Type = Content.self) async throws -> Content.WebScrapingOutput {
        if self.configuration.useCaching {
            if let content = await self.tryLoadJSON(Content.self, from: self.cacheFile(for: type)) {
                return content
            }
            // em caso de erro, ignora o cache
        }
        return try await self.scrapeFresh(type)
    }

    /// Faz o scraping de um conteúdo novo e sobrescreve o arquivo de caching.
    @inlinable
    func scrapeFresh<Content: WebScrapable>(
        _ type: Content.Type = Content.self
    ) async throws -> Content.WebScrapingOutput {
        self.logger.info("Scraping fresh content...", metadata: [
            "content": "\(Content.self)",
            "service": "\(Self.self)"
        ])

        let (elapsed, content) = try await withTiming {
            try await Content.scrape(with: self)
        }
        self.logger.info("Content fully scraped after \(elapsed) seconds.", metadata: [
            "content": "\(Content.self)",
            "service": "\(Self.self)",
            "content-size": "\(Content.size(of: content))"
        ])

        if self.configuration.useCaching {
            // faz o salvamento do cache em outra task, sem travar essa
            Task { await self.trySaveJSON(content, at: self.cacheFile(for: type)) }
        }
        return content
    }

    /// Tenta executar `loadJSON` ou acusa um erro pelo `logger`.
    ///
    /// Usa o FileManager por ser mais simples, já que essa função roda no background.
    private func tryLoadJSON<Content: WebScrapable>(
        _ type: Content.Type = Content.self,
        from path: String
    ) async -> Content.WebScrapingOutput? {
        do {
            let content = try await self.loadJSON(Content.WebScrapingOutput.self, from: path)

            self.logger.info("Scraped content loaded from JSON file", metadata: [
                "content": "\(Content.self)",
                "file-path": .string(path),
                "service": "\(Self.self)",
                "content-size": "\(Content.size(of: content))"
            ])
            return content
        } catch {
            self.logger.report(
                level: .info,
                error,
                Service: Self.self,
                additional: "Could not load scraped content from JSON file",
                metadata: ["content": "\(Content.self)", "file-path": path]
            )
            return nil
        }
    }

    /// Tenta executar `saveJSON` ou acusa um erro pelo `logger`.
    ///
    /// Usa o FileManager por ser mais simples, já que essa função roda no background.
    private func trySaveJSON<Content: Codable>(_ content: Content, at path: String) async {
        do {
            try await self.saveJSON(content, at: path)
        } catch {
            self.logger.report(
                level: .error,
                error,
                Service: Self.self,
                additional: "Could not save scraped content to JSON file",
                metadata: ["content": "\(Content.self)", "file-path": path]
            )
        }
    }

    /// Faz a leitura do arquivo em `path` e converte para `Content` usando um decoder de JSON.
    ///
    /// Usa o NonBlockingFileIO do swift-nio, por ser async e bem eficiente.
    private func loadJSON<Content: Decodable>(
        _ type: Content.Type = Content.self,
        from path: String
    ) async throws -> Content {
        let eventLoop = self.app.eventLoopGroup.next()
        let file = try await self.app.fileio.openFile(path: path, mode: .read, eventLoop: eventLoop).get()
        let byteCount = try await self.app.fileio.readFileSize(fileHandle: file, eventLoop: eventLoop).get()

        var content = try await self.app.fileio.read(
            fileHandle: file,
            byteCount: Int(byteCount),
            allocator: ByteBufferAllocator(),
            eventLoop: eventLoop
        ).get()
        try file.close()

        let data = content.readData(length: content.readableBytes)
        return try JSONDecoder().decode(type, from: data ?? Data())
    }

    /// Salva `content` como um arquivo JSON em `path`.
    private func saveJSON<Content: Codable>(_ content: Content, at path: String) async throws {
        let data = try JSONEncoder().encode(content)

        try self.ensureDirectoryExists(at: self.cacheDirectory)
        self.removeFileIfExists(at: path)

        try self.createFileWith(contents: data, at: path)
    }
}

extension WebScraper {
    // MARK: - Arquivos e diretórios

    /// Diretório usado para caching dos resultados de parsing.
    var cacheDirectory: URL {
        var resources = URL(fileURLWithPath: self.app.directory.resourcesDirectory, isDirectory: true)
        // remove partes como "/" e "." do nome da pasta antes de inserir na URL
        resources.appendPathComponent(self.configuration.cacheDirectory.replacingNonAlphaNum(), isDirectory: true)
        resources.standardize()
        return resources
    }

    /// Path do arquivo usado para caching de `Content`.
    @inlinable
    func cacheFile<Content: WebScrapable>(for content: Content.Type) -> String {
        // remove partes como "/" e "." do nome do arquivo para sempre funcionar corretamente
        let filename = "\(Content.cacheFile.replacingNonAlphaNum()).json"
        return self.cacheDirectory.appendingPathComponent(filename, isDirectory: false).path
    }

    /// Tenta remover toda a pasta de cache, ignorando erros.
    private func clearCacheDirectory() {
        try? FileManager.default.removeItem(at: self.cacheDirectory)
    }

    /// Tenta remover arquivo em `path`, ignorando erros.
    private func removeFileIfExists(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Checa que `path` existe e é uma pasta ou cria uma nova.
    private func ensureDirectoryExists(at path: URL) throws {
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory)

        if !(exists && isDirectory.boolValue) {
            try? FileManager.default.removeItem(at: path)

            try FileManager.default.createDirectory(
                at: self.cacheDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    /// Cria arquivo em `path` com um conteúdo predefinido.
    private func createFileWith(contents: Data, at path: String) throws {
        let successful = FileManager.default.createFile(
            atPath: path,
            contents: contents
        )

        if !successful {
            throw FileCreationError(at: path, with: contents)
        }
    }

    /// Erro durante a criação do arquivo.
    private struct FileCreationError: DebuggableError {
        let path: String
        let contents: Data?
        let attributes: [FileAttributeKey: Any]

        var contentSize: Int {
            self.contents?.count ?? 0
        }

        init(
            at path: String,
            with contents: Data? = nil,
            with attributes: [FileAttributeKey: Any] = [:],
            source: ErrorSource = .capture(),
            stackTrace: StackTrace? = .capture()
        ) {
            self.path = path
            self.contents = contents
            self.attributes = attributes

            self.source = source
            self.stackTrace = stackTrace
        }

        // MARK: - DebuggableError

        let stackTrace: StackTrace?

        let source: ErrorSource?

        var logLevel: Logger.Level {
            .error
        }

        var identifier: String {
            "FileCreationError"
        }

        var reason: String {
            "Could not a create file (\(self.contentSize) bytes) at \(self.path) (unknown reason)."
        }
    }
}
