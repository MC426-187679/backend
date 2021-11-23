@testable import App
import XCTVapor
import XCTest

final class SearchAPITests: XCTestCase {

    // MARK: - Montagem da URL do curso

    /// Constrói a URL para busca incluindo parâmetros.
    private func url(search query: String, limit: String? = nil) -> String {
        var url = URL(string: "api/busca")!
        url = url.appending("query", value: query)
        if let limit = limit {
            url = url.appending("limit", value: limit)
        }

        return url.absoluteString
    }

    private func url(course code: String, variant: String? = nil) -> String {
        if let variant = variant {
            return "api/curso/\(code)/\(variant)/"
        } else {
            return "api/curso/\(code)/"
        }
    }

    // MARK: - Testes

    func testSearchWithStringAsLimit() throws {
        try assertBadRequest(on: url(search: "mc102", limit: "cinco"))
    }

    func testSearchWithFloatAsLimit() throws {
        try assertBadRequest(on: url(search: "mc102", limit: "10.0"))
    }

    func testSearchWithEmptyQuery() throws {
        try assertJsonResult(on: url(search: ""), matches: [])
    }

    func testSearchWithNegativeLimit() throws {
        try assertBadRequest(on: url(search: "mc102", limit: "-1"))
    }

    func testSearchWithZeroLimit() throws {
        try assertBadRequest(on: url(search: "mc102", limit: "0"))
    }

    func testSearchWithValidDisciplineCodeAndLimit() throws {
        let limit = SearchController.maxSearchLimit - 1
        try assertJsonSize(on: url(search: "mc102", limit: "\(limit)"), size: limit)
    }

    func testSearchWithValidDisciplineCodeAndHugeLimit() throws {
        let limit = SearchController.maxSearchLimit + 1
        try assertJsonSize(on: url(search: "mc102", limit: "\(limit)"), size: SearchController.maxSearchLimit)
    }

    // MARK: - Testes Qualitativos

    func testSearchQuality() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        // Pega uma disciplina aleatória do curso 34 e segunda proficiência
        try app.test(.GET, url(course: "34", variant: "2"), afterResponse: { res in
            let courseDisc = JSONValue(fromJson: res.body.string)?.asArray()
            let randomSemester = courseDisc?.randomElement()?.asArray()
            let randomDiscipline = randomSemester?.randomElement()?.asString()
            XCTAssertNotNil(randomDiscipline)
            let discUrl = self.url(search: randomDiscipline!, limit: "10")

            // Faz uma busca com a disciplina aleatória e verifica se é a primeira da pesquisa
            try app.test(.GET, discUrl, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.content.contentType, .json)
                let disc = JSONValue(res.body.string)?.asArray()?.first?.asObject()
                XCTAssertNotNil(disc)
                XCTAssertEqual(disc!["code"]?.asString(), randomDiscipline!)
            })
        })

    }
}
