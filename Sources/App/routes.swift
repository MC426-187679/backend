import Vapor

func routes(_ app: Application) throws {
    let api = app.grouped("api")

    /// Parâmetros de busca textual.
    struct SearchParams: Content {
        let query: String
        let limit: Int?
    }

    // API: busca textual entre vários elementos.
    api.get("busca") { req -> EventLoopFuture<[Match]> in

        let params = try req.query.decode(SearchParams.self)
        // roda em async para não travar a aplicação
        // https://docs.vapor.codes/4.0/async/#blocking
        return req.application.threadPool.runIfActive(eventLoop: req.eventLoop) {
            return req.scrapedData.search(
                for: params.query,
                limitingTo: params.limit ?? 100,
                maxScore: 0.9
            )
        }
    }

    // API: dados para a página de uma disciplina
    api.get("disciplina", ":code") { req -> Discipline in
        // SAFETY: o router do Vapor só deixa chegar aqui com o parâmetro
        let code = req.parameters.get("code")!

        guard let result = req.scrapedData.getDiscipline(with: code) else {
            // retorna 404 NOT FOUND
            throw Abort(.notFound)
        }
        return result
    }
}
