@testable import App
import XCTVapor

final class CourseAPITests: APITestCase {

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
            "name": "Engenharia de Computação",
            "code": "34",
            "variants": [
                ["code": "AA", "name": "Sistemas de Computação"],
                ["code": "AB", "name": "Sistemas e Processos Industriais"],
                ["code": "AX", "name": "Para Matrícula Antes da Opção"]
            ]
        ])
    }

    // swiftlint:disable function_body_length
    func testFetchCourseWithWithVariantsAndValidCodeAndValidVariant() throws {
        try assertJsonResult(on: url(course: "34", variant: "2"), matches: [
            [
                "disciplines": [
                    ["code": "F 128", "credits": 4],
                    ["code": "F 129", "credits": 2],
                    ["code": "HZ291", "credits": 2],
                    ["code": "MA111", "credits": 6],
                    ["code": "MA141", "credits": 4],
                    ["code": "MC102", "credits": 6],
                    ["code": "QG111", "credits": 2],
                    ["code": "QG122", "credits": 2]
                ],
                "electives": 0
            ],
            [
                "disciplines": [
                    ["code": "F 228", "credits": 4],
                    ["code": "F 229", "credits": 2],
                    ["code": "LA122", "credits": 4],
                    ["code": "MA211", "credits": 6],
                    ["code": "MA327", "credits": 4],
                    ["code": "MC202", "credits": 6]
                ],
                "electives": 0
            ],
            [
                "disciplines": [
                    ["code": "EA513", "credits": 4],
                    ["code": "F 315", "credits": 4],
                    ["code": "F 328", "credits": 4],
                    ["code": "F 329", "credits": 2],
                    ["code": "MA311", "credits": 6],
                    ["code": "MC322", "credits": 4]
                ],
                "electives": 0
            ],
            [
                "disciplines": [
                    ["code": "EA614", "credits": 4],
                    ["code": "EA772", "credits": 4],
                    ["code": "F 428", "credits": 4],
                    ["code": "F 429", "credits": 2],
                    ["code": "MC358", "credits": 4],
                    ["code": "MC404", "credits": 4]
                ],
                "electives": 0
            ],
            [
                "disciplines": [
                    ["code": "EA773", "credits": 4],
                    ["code": "EA871", "credits": 4],
                    ["code": "EA876", "credits": 4],
                    ["code": "EE400", "credits": 4],
                    ["code": "EE532", "credits": 4],
                    ["code": "MC458", "credits": 4],
                    ["code": "ME323", "credits": 4]
                ],
                "electives": 0
            ],
            [
                "disciplines": [
                    ["code": "EA202", "credits": 6],
                    ["code": "EA872", "credits": 2],
                    ["code": "EA960", "credits": 4],
                    ["code": "EE534", "credits": 2],
                    ["code": "EM423", "credits": 3],
                    ["code": "MS211", "credits": 4]
                ],
                "electives": 0
            ],
            [
                "disciplines": [
                    ["code": "EA074", "credits": 4],
                    ["code": "EA201", "credits": 6],
                    ["code": "EA616", "credits": 4],
                    ["code": "EA619", "credits": 2],
                    ["code": "EA979", "credits": 4]
                ],
                "electives": 0
            ],
            [
                "disciplines": [
                    ["code": "BE310", "credits": 2],
                    ["code": "EA072", "credits": 4],
                    ["code": "EA080", "credits": 2],
                    ["code": "EA721", "credits": 4],
                    ["code": "EA722", "credits": 2],
                    ["code": "EG950", "credits": 6]
                ],
                "electives": 5
            ],
            [
                "disciplines": [
                    ["code": "CE304", "credits": 2],
                    ["code": "CE838", "credits": 2],
                    ["code": "EA006", "credits": 6],
                    ["code": "EA044", "credits": 4],
                    ["code": "EE610", "credits": 4]
                ],
                "electives": 8
            ],
            [
                "disciplines": [
                    ["code": "CE738", "credits": 4]
                ],
                "electives": 16
            ]
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
            "name": "Engenharia Elétrica",
            "code": "11",
            "variants": []
        ])
    }

    func testFetchCourseWithValidCodeAndInvalidVariantSelected() throws {
        try assertNotFound(on: url(course: "11", variant: "1"))
    }
}
