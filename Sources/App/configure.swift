import Foundation
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // recupera dados por scraping
    app.storage[ScrapedData.self] = try .init(app)

    // register routes
    try routes(app)
}

/// Controlador de dados recuperados por Web Scraping.
class ScrapedData: StorageKey {
    typealias Value = ScrapedData
    /// Controlador de disciplinas.
    private let disciplines: Discipline.Controller

    fileprivate init(_ app: Application) throws {
        self.disciplines = try .init(logger: app.logger)
    }

    /// Recupera uma disciplina pelo seu código.
    func getDiscipline(withCode code: String) -> Discipline? {
        self.disciplines.get(code: code)
    }
}

extension Application {
    /// Dados recuperados por scraping.
    var scrapedData: ScrapedData? {
        get { self.storage[ScrapedData.self] }
    }
}

extension Request {
    /// Dados recuperados por scraping.
    var scrapedData: ScrapedData {
        // SAFETY: sempre vai estar inicializado em Request
        get { self.application.scrapedData! }
    }
}
