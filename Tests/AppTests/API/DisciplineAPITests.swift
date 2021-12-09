@testable import App
import XCTVapor

final class DisciplineAPITests: APITestCase {

    // MARK: - Montagem da URL do curso

    /// Constrói a URL para acesso dos dados de uma disciplina.
    private func url(discipline code: String) -> String {
        return "api/disciplina/\(code)"
    }

    // MARK: - Testes

    func testFetchDisciplineWithValidCode() throws {
        let expectedSyllabus = "Conceitos básicos de organização de computadores."
            + " Construção de algoritmos e sua representação em pseudocódigo e linguagens de alto nível."
            + " Desenvolvimento sistemático e implementação de programas."
            + " Estruturação, depuração, testes e documentação de programas."
            + " Resolução de problemas."

        try assertJsonResult(on: url(discipline: "MC102"), matches: [
            "code": "MC102",
            "name": "Algoritmos e Programação de Computadores",
            "syllabus": .string(expectedSyllabus),
            "credits": 6,
            "reqs": [],
            "reqBy": [
                "CV074", "CV632", "EA044", "EA060", "EA869", "EA954",
                "EG940", "EM008", "EM024", "EQ048", "F 790", "FA103",
                "FA374", "MC202", "MC886", "MC949", "ME315", "MS211",
                "MS505", "MS614"
            ]
        ])

    }

    func testFetchDisciplineWithCodeCharacterCountBiggerThan5() throws {
        try assertNotFound(on: url(discipline: "MC1022"))
    }

    func testFetchDisciplineWithCodeCharacterCountLowerThan5() throws {
        try assertNotFound(on: url(discipline: "MC10"))
    }

    func testFetchDisciplineWithSpecialCasesCode() throws {
        try assertNotFound(on: url(discipline: "AA200"))
    }

    func testFetchDisciplineWithLowerCaseCode() throws {
        try assertNotFound(on: url(discipline: "mc102"))
    }
}
