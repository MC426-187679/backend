@testable import App
import XCTVapor

/// Interface de funções para teste.
class APITestCase: XCTestCase {
    /// Instância estática da aplicação, que alterada em cada TestCase.
    static var app = Result { () -> Application in
        throw CancellationError()
    }

    /// Acesso da isntância atual.
    var app: Application {
        get throws {
            try Self.app.get()
        }
    }

    /// Inicializa nova aplicação.
    override class func setUp() {
        self.app = Result { () -> Application in
            let app = Application(.testing)
            try configure(app)

            try app.waitInitialization()
            return app
        }
    }

    /// Encerra aplicação anterior.
    override class func tearDown() {
        if case .success(let app) = self.app {
            app.shutdown()
            self.app = .failure(CancellationError())
        }
    }

    /// Checa se o acesso no endpoint do servidor retorna o resultado esperado em JSON.
    func assertJsonResult(on endpoint: String, matches expectedValue: JSONValue) throws {
        try app.test(.GET, endpoint, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType, .json)
            XCTAssertJSON(text: res.body.string, matches: expectedValue)
        })
    }

    /// Checa se o acesso no endpoint do servidor retorna um resultado com tamanho esperado em JSON.
    func assertJsonSize(on endpoint: String, size: Int) throws {
        try app.test(.GET, endpoint, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType, .json)
            XCTAssertEqual(JSONValue(fromJson: res.body.string)?.asArray()?.count, size)
        })
    }

    /// Assegura que o endpoint não existe no servidor.
    func assertNotFound(on endpoint: String) throws {
        try assertStatus(on: endpoint, for: .notFound)
    }

    /// Assegura que o servidor não aceitou a requisição por ser feita de forma errada.
    func assertBadRequest(on endpoint: String) throws {
        try assertStatus(on: endpoint, for: .badRequest)
    }

    // MARK: - Métodos auxiliares

    /// Assegura que a requisição retorna com um status igual a `status`.
    private func assertStatus(on endpoint: String, for status: HTTPStatus) throws {
        try app.test(.GET, endpoint, afterResponse: { res in
            XCTAssertEqual(res.status, status)
        })
    }
}
