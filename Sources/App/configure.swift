import Foundation
import Vapor
import Services

/// Future usada em Vapor e NIO.
typealias Future<T> = EventLoopFuture<T>

// configures your application
public func configure(_ app: Application) throws {
    app.http.server.configuration.serverName = "Planejador de Disciplinas"
    // serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // quando em modo de desenvolvimento
    if case .development = app.environment {
        // envia scores nas matches da busca
        Match.encodeScoresForSending()
        // formata JSON com chaves ordenadas e identadas
        let encoder = ContentConfiguration.global.jsonEncoder ?? .init()
        encoder.outputFormatting.formUnion([.sortedKeys, .prettyPrinted])
        ContentConfiguration.global.use(encoder: encoder, for: .json)
    }
    // recupera dados por scraping
    app.storage[ScrapedData.self] = try .init(app)
    // register routes
    try routes(app)
}

extension Application {
    /// Executa closure assincronamente em `eventLoop`.
    func async<T>(on eventLoop: EventLoop, run: @escaping () throws -> T) -> Future<T> {
        self.threadPool.runIfActive(eventLoop: eventLoop, run)
    }

    /// Executa closure assincronamente.
    func async<T>(run: @escaping () throws -> T) -> Future<T> {
        self.async(on: self.eventLoopGroup.next(), run: run)
    }
}

extension ContentConfiguration {
    /// Encoder de JSON na configuração atual.
    var jsonEncoder: JSONEncoder? {
        do {
            return try self.requireEncoder(for: .json) as? JSONEncoder
        } catch {
            return nil
        }
    }
}

extension Request {
    /// Dados recuperados por scraping.
    var scrapedData: ScrapedData {
        // SAFETY: sempre vai estar inicializado em Request
        self.application.storage[ScrapedData.self]!
    }
}

/// Controlador de dados recuperados por Web Scraping.
final class ScrapedData: StorageKey {
    typealias Value = ScrapedData
    /// Logger da aplicação, para reutilizar depois.
    private let logger: Logger
    /// Controlador de disciplinas.
    private let disciplines: Discipline.Controller

    fileprivate init(_ app: Application) throws {
        // inicia thread para preparar os dados
        let disciplines = app.async {
            try Discipline.Controller(logger: app.logger)
        }
        // então monta o controlador global
        self.logger = app.logger
        self.disciplines = try disciplines.wait()
    }

    /// Recupera uma disciplina pelo seu código.
    func getDiscipline(with code: String) -> Discipline? {
        self.disciplines.get(code: code)
    }

    /// Busca textual dentre os dados carregados na memória.
    ///
    /// - Returns: Os `limit` melhores scores dentre todos os
    ///   os conjuntos de dados, mas com score menor que
    ///   `maxScore`.
    func search(for text: String, limitingTo limit: Int, maxScore: Double) -> [Match]  {
        let (elapsed, matches) = withTiming {
            self.disciplines.search(for: text, limitedTo: limit, upTo: maxScore)
        }
        self.logger.info("Searched for \"\(text)\" with \(matches.count) results in \(elapsed) secs.")

        return matches
    }
}
