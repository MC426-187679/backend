import Vapor

func routes(_ app: RoutesBuilder) {
    // Página principal: carrega o frontend
    app.get("") { req in
        getIndexHTML(for: req)
    }

    // endpoint para requisições da API
    api_routes(app.grouped("api"))

    // Fallback: deixa o frontend tratar
    app.get("**") { req in
        getIndexHTML(for: req)
    }
}

/// Carrega o HTML gerado pelo frontend.
private func getIndexHTML(for req: Request) -> Response {
    req.fileio.streamFile(at: "Public/index.html", mediaType: .html)
}

/// Rotas usadas pela API.
private func api_routes(_ api: RoutesBuilder) {
    // API: resposta padrão
    api.get("") { _ -> Response in
        throw Abort(.noContent)
    }

    // API: busca textual entre vários elementos.
    api.get("busca") { req in
        await req.searchController.searchFor(
            params: try req.query.decode(SearchParams.self)
        )
    }

    // WebSocket: busca textual entre vários elementos.
    api.webSocket("busca", "ws") { req, wsock in
        let encoder = ContentConfiguration.global.jsonEncoder ?? JSONEncoder()

        // para cada query, envia os resultados da busca em json
        wsock.onText { wsock, text in
            let results = await req.searchController.searchFor(query: text)

            if let data = try? encoder.encode(results) {
                wsock.send(raw: data, opcode: .text)
            } else {
                wsock.send("[]")
            }
        }
    }

    // API: dados para a página de uma disciplina
    api.get("disciplina", ":code") { req in
        try await req.disciplines.fetchDiscipline(
            code: try req.parameters.require("code")
        )
    }

    // API: dados para a página de um curso
    api.get("curso", ":code") { req in
        try await req.courses.fetchCourse(
            code: try req.parameters.require("code")
        )
    }

    // API: dados para a página de árvore do curso
    api.get("curso", ":code", ":variant") { req in
        try await req.courses.fetchCourseTree(
            code: try req.parameters.require("code"),
            variant: try req.parameters.require("variant")
        )
    }

    // API: desconhecida
    api.get("**") { _ -> Response in
        throw Abort(.badRequest)
    }
}
