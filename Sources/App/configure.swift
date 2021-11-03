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
    
    try initializeControllers(app)
    
    // register routes
    try routes(app)
}

private func initializeControllers(_ app: Application) throws {
    // Inicia thread para preparar os dados.
    // Pega instância de singleton pela primeira vez para
    // carregar os dados de forma assíncrona.
    // `.shared` é lazy por ser estático, e por isso
    // roda de forma assíncrona abaixo.
    let disciplines = app.async {
        Discipline.Controller.shared
    }
    let courses = app.async {
        Course.Controller.shared
    }
    let _ = try disciplines.wait()
    let _ = try courses.wait()
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

