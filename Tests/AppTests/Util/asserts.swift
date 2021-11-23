import App
import XCTVapor

// MARK: - Interface de funções para teste

/// Checa se o acesso no endpoint do servidor retorna o resultado esperado em JSON.
func assertJsonResult(
    on endpoint: String,
    matches expectedValue: JSONValue,
    environment: Environment = .testing
) throws {
    let app = Application(environment)
    defer { app.shutdown() }
    try configure(app)

    try app.test(.GET, endpoint, afterResponse: { res in
        XCTAssertEqual(res.status, .ok)
        XCTAssertEqual(res.content.contentType, .json)
        XCTAssertJSON(text: res.body.string, matches: expectedValue)
    })
}

/// Checa se o acesso no endpoint do servidor retorna um resultado com tamanho esperado em JSON.
func assertJsonSize(
    on endpoint: String,
    size: Int,
    environment: Environment = .testing
) throws {
    let app = Application(environment)
    defer { app.shutdown() }
    try configure(app)

    try app.test(.GET, endpoint, afterResponse: { res in
        XCTAssertEqual(res.status, .ok)
        XCTAssertEqual(res.content.contentType, .json)
        XCTAssertEqual(JSONValue(res.body.string)?.asArray()?.count, size)
    })
}

/// Assegura que o endpoint não existe no servidor.
func assertNotFound(
    on endpoint: String,
    environment: Environment = .testing
) throws {
    try assertStatus(on: endpoint, for: .notFound)
}

/// Assegura que o servidor não aceitou a requisição por ser feita de forma errada.
func assertBadRequest(
    on endpoint: String,
    environment: Environment = .testing
) throws {
    try assertStatus(on: endpoint, for: .badRequest)
}

// MARK: - Métodos auxiliares

/// Assegura que a requisição retorna com um status igual a `status`.
private func assertStatus(
    on endpoint: String,
    for status: HTTPStatus,
    environment: Environment = .testing
) throws {
    let app = Application(environment)
    defer { app.shutdown() }
    try configure(app)

    try app.test(.GET, endpoint, afterResponse: { res in
        XCTAssertEqual(res.status, status)
    })
}
