import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "It works!"
    }

    // API: dados para a página de uma disciplina
    app.get("api", "disciplina", ":code") { req -> Discipline in
        // SAFETY: o router do Vapor só deixa chegar aqui com o parâmetro
        let code = req.parameters.get("code")!

        guard let result = req.scrapedData.getDiscipline(withCode: code) else {
            // retorna 404 NOT FOUND
            throw Abort(.notFound)
        }
        return result
    }
}
