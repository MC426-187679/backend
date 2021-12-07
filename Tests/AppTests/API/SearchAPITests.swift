@testable import App
import XCTVapor
import XCTest

final class SearchAPITests: APITestCase {

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
        let defaultLimit = SearchParams.configuration.defaultSearchLimit
        try assertJsonSize(on: url(search: ""), size: Int(defaultLimit))
    }

    func testSearchWithNegativeLimit() throws {
        try assertBadRequest(on: url(search: "mc102", limit: "-1"))
    }

    func testSearchWithZeroLimit() throws {
        try assertJsonResult(on: url(search: "mc102", limit: "0"), matches: [])
    }

    func testSearchWithValidDisciplineCodeAndLimit() throws {
        let limit = SearchParams.configuration.maxSearchLimit - 1
        try assertJsonSize(on: url(search: "mc102", limit: "\(limit)"), size: Int(limit))
    }

    func testSearchWithValidDisciplineCodeAndHugeLimit() throws {
        let limit = SearchParams.configuration.maxSearchLimit + 1
        try assertJsonSize(
            on: url(search: "mc102", limit: "\(limit)"),
            size: Int(SearchParams.configuration.maxSearchLimit)
        )
    }

    // MARK: - Testes Qualitativos

    func testSearchQuality() throws {
        // Pega uma disciplina aleatória do curso 34 e segunda proficiência
        try app.test(.GET, url(course: "34", variant: "2"), afterResponse: { res in
            let courseDisc = JSONValue(fromJson: res.body.string)?.asArray()
            let randomSemester = courseDisc?.randomElement()?.asObject() ?? [:]
            let randomDiscipline = randomSemester["disciplines"]?.asArray()?.randomElement()?.asObject() ?? [:]
            let randomCode = randomDiscipline["code"]?.asString() ?? ""
            XCTAssertNotEqual(randomCode, "")

            let discUrl = self.url(search: randomCode, limit: "10")

            // Faz uma busca com a disciplina aleatória e verifica se é a primeira da pesquisa
            try app.test(.GET, discUrl, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.content.contentType, .json)
                let disc = JSONValue(fromJson: res.body.string)?.asArray()?.first?.asObject() ?? [:]
                XCTAssertNotEqual(disc, [:])
                XCTAssertEqual(disc["code"]?.asString(), randomCode)
            })
        })

    }
}
