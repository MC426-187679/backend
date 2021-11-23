@testable import App
import XCTVapor

final class CourseAPITests: XCTestCase {

    // MARK: - Montagem da URL do curso

    /// Constrói a URL para acesso do curso ou de sua modalidade.
    private func url(course code: String, variant: String? = nil) -> String {
        if let variant = variant {
            return "api/curso/\(code)/\(variant)/"
        } else {
            return "api/curso/\(code)/"
        }
    }

    // MARK: - Testes

    func testFetchCourseWithVariantsAndValidCodeAndNoVariantSelected() throws {
        try assertJsonResult(on: url(course: "34"), matches: [
            "name": "Engenharia de Computação - Integral",
            "code": "34",
            "variant": [
                "AA - Sistemas de Computação",
                "AB - Sistemas e Processos Industriais",
                "AX - Para Matrícula Antes da Opção",
            ],
        ])
    }

    func testFetchCourseWithWithVariantsAndValidCodeAndValidVariant() throws {
        try assertJsonResult(on: url(course: "34", variant: "2"), matches: [
            ["F 128", "F 129", "HZ291", "MA111", "MA141", "MC102", "QG111", "QG122"],
            ["F 228", "F 229", "LA122", "MA211", "MA327", "MC202"],
            ["EA513", "F 315", "F 328", "F 329", "MA311", "MC322"],
            ["EA614", "EA772", "F 428", "F 429", "MC358", "MC404"],
            ["EA773", "EA871", "EA876", "EE400", "EE532", "MC458", "ME323"],
            ["EA202", "EA872", "EA960", "EE534", "EM423", "MS211"],
            ["EA074", "EA201", "EA616", "EA619", "EA979"],
            ["BE310", "EA072", "EA080", "EA721", "EA722", "EG950"],
            ["CE304", "CE838", "EA006", "EA044", "EE610"],
            ["CE738"],
        ])
    }

    func testFetchCourseWithWithVariantsAndValidCodeAndInvalidVariant() throws {
        try assertNotFound(on: url(course: "34", variant: "3"))
    }


    func testFetchCourseWithInvalidCodeAndNoVariantSelected() throws {
        try assertNotFound(on: url(course: "0"))
    }

    func testFetchCourseWithInvalidCodeAndAnyVariantSelected() throws {
        try assertNotFound(on: url(course: "0", variant: "7"))
    }

    func testFetchCourseWithValidCodeAndNoVariantSelected() throws {
        try assertJsonResult(on: url(course: "11"), matches: [
            "name": "Engenharia Elétrica - Integral",
            "code": "11"
        ])
    }

    func testFetchCourseWithValidCodeAndValidVariantSelected() throws {
        try assertJsonResult(on: url(course: "11", variant: "0"), matches: [
            ["EA772", "EM230", "EM312", "F 128", "F 129", "MA111", "MA141"],
            ["EA513", "EA773", "F 228", "F 229", "MA211", "MA327", "MC102"],
            ["EA611", "EA869", "EE103", "EM524", "F 315", "MA311", "ME323"],
            ["EA871", "EE300", "EE301", "EE400", "EE521", "LA122", "MS211", "QG111", "QG122"],
            ["EA075", "EA614", "EE410", "EE522", "EE540", "EM423", "ET520", "ET521"],
            ["EA616", "EA619", "EA879", "EE530", "EE754", "EE881", "ET620", "ET621"],
            ["EA076", "EA721", "EA722", "EE531", "EE640", "EE755", "EE882", "ET720", "ET911"],
            ["CE738", "CE838", "EA044", "EE610", "EE641", "EE833"],
            ["BE310", "CE304", "EA006"],
            [],
        ])
    }

    func testFetchCourseWithValidCodeAndInvalidVariantSelected() throws {
        try assertNotFound(on: url(course: "11", variant: "1"))
    }
}
