import Vapor

func routes(_ app: Application) throws {
    let api = app.grouped("api")

    /// Parâmetros de busca textual.
    struct SearchParams: Content {
        let query: String
        let limit: Int?
    }

    // API: busca textual entre vários elementos.
    api.get("busca") { req -> Future<[Match]> in

        let params = try req.query.decode(SearchParams.self)
        // roda em async para não travar a aplicação
        // https://docs.vapor.codes/4.0/async/#blocking
        return req.application.async(on: req.eventLoop) {
            req.scrapedData.search(
                for: params.query,
                limitingTo: params.limit ?? 100,
                maxScore: 0.99
            )
        }
    }

    // API: dados para a página de uma disciplina
    api.get("disciplina", ":code") { req -> Discipline in
        // SAFETY: o router do Vapor só deixa chegar aqui com o parâmetro
        let code = req.parameters.get("code")!

        guard let discipline = req.scrapedData.getDiscipline(with: code) else {
            // retorna 404 NOT FOUND
            throw Abort(.notFound)
        }

        return discipline
    }

    // API: dados para a página de um curso
    api.get("curso", ":code") { req -> Course in
        // SAFETY: o router do Vapor só deixa chegar aqui com o parâmetro
        let code = req.parameters.get("code")!

        guard let course = req.scrapedData.getCourse(with: code) else {
            throw Abort(.notFound)
        }

        return course
    }

    // API: dados para a página de árvore do curso
    api.get("curso", ":code", ":variant") { req -> CourseTree in
        // SAFETY: o router do Vapor só deixa chegar aqui com os parâmetros
        let code = req.parameters.get("code")!
        let variant = req.parameters.get("variant")!

        guard
            let index = Int(variant),
            let course = req.scrapedData.getCourse(with: code),
            let tree = course.getTree(forIndex: index)
        else {
            throw Abort(.notFound)
        }

        return tree
    }
}
