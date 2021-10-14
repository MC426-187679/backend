import Foundation
import Services
import Vapor


/// Representação de uma matéria.
struct Discipline: Content {
    /// Código da disciplina.
    let code: String
    /// Nome da disciplina.
    let name: String
    /// Número de créditos.
    let credits: Int
    /// Grupos de requisitos da disciplina.
    let reqs: [[Requirement]]?
    /// Disciplina que tem essa como requisito.
    let reqBy: [String]?
    /// Ementa da disciplina.
    let syllabus: String
}

/// Requisito de uma disciplina.
struct Requirement: Content {
    /// Código de requisito.
    let code: String
    /// Se o requisito é parcial.
    let partial: Bool?
    /// Se o requisito não é uma disciplina propriamente.
    let special: Bool?
}

extension Discipline: WebScrapable {
    static let scriptName = "disciplines.py"
}

extension Discipline: Searchable {
    /// Ordena por código, para buscar mais rápido.
    static let sortOn: Properties? = .code

    /// Propriedades buscáveis na disciplina.
    enum Properties: SearchableProperty {
        typealias Of = Discipline

        /// Busca por código da disciplina.
        case code
        /// Busca pelo nome da disciplina.
        case name
        /// Busca pela ementa da disciplina.
        case syllabus

        @inlinable
        func get(from item: Discipline) -> String {
            switch self {
                case .code:
                    return item.code
                case .name:
                    return item.name
                case .syllabus:
                    return item.syllabus
            }
        }

        @inlinable
        var weight: Double {
            switch self {
                // maior peso para o código, que é mais exato
                case .code:
                    return 0.6
                case .name:
                    return 0.3
                case .syllabus:
                    return 0.1
            }
        }
    }
}

extension Discipline: Matchable {
    /// Forma reduzida da disciplina, com
    /// apenas nome e código.
    struct ReducedForm: Encodable {
        let code: String
        let name: String
    }

    @inlinable
    func reduced() -> ReducedForm {
        .init(code: self.code, name: self.name)
    }
}
