import Foundation
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // config do servidor
    app.http.server.configuration.serverName = "Planejador de Disciplinas"
    if case .production = app.environment {
        app.http.server.configuration.responseCompression = .enabled
    }
    // config do client
    app.http.client.configuration.httpVersion = .http1Only
    app.http.client.configuration.connectionPool.concurrentHTTP1ConnectionsPerHostSoftLimit = 24
    app.http.server.configuration.hostname = "0.0.0.0"

    // serve arquivo da pasta /Public
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // formata melhor o JSON no modo de desenvolvimento
    if case .development = app.environment {
        enablePrettyPrintForJSON()
        app.searchCache.configuration.sendHiddenFields = true
        app.searchCache.configuration.sendScore = true
    }

    // inicalização dos controladores e das rotas
    app.initialize(controller: Discipline.Controller.self)
    app.initialize(controller: Course.Controller.self)
    routes(app)

    // comando para somente buildar o cache e sair
    app.commands.use(BuildCache(), as: "build-cache")
}

/// Formata output de JSON com chaves ordenadas e identadas.
private func enablePrettyPrintForJSON() {
    let globalEncoder = try? ContentConfiguration.global.requireEncoder(for: .json)
    let encoder = globalEncoder as? JSONEncoder ?? JSONEncoder()

    encoder.outputFormatting.formUnion([.sortedKeys, .prettyPrinted])
    ContentConfiguration.global.use(encoder: encoder, for: .json)
}

/// Comando para somente buildar o cache do web scraping e sair.
struct BuildCache: Command {
    struct Signature: CommandSignature { }

    let help = "Run web scraping script, save cache and exit."

    func run(using context: CommandContext, signature: Signature) throws {
        let task = context.application.eventLoopGroup.performWithTask {
            _ = try? await context.application.instance(controller: Discipline.Controller.self)
            _ = try? await context.application.instance(controller: Course.Controller.self)
        }
        try task.wait()
    }
}
