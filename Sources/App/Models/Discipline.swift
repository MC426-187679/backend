import Foundation
import Services
import Vapor


/// Representação de uma matéria.
struct Discipline: Content {
    /// Código da disciplina.
    let code: String
    /// Nome da disciplina.
    let name: String
    /// Grupos de requisitos da disciplina.
    let reqs: [[Requirement]]?
    /// Disciplina que tem essa como requisito.
    let reqBy: [String]?
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
    typealias Properties = DisciplineProperties

    static let sortOn: Properties? = .code

    /// Propriedades buscáveis na disciplina.
    enum DisciplineProperties: SearchableProperty {
        typealias Of = Discipline

        /// Busca por código da disciplina.
        case code
        /// Busca pelo nome da disciplina.
        case name

        func getter(_ item: Discipline) -> String {
            switch self {
                case .code:
                    return item.code
                case .name:
                    return item.name
            }
        }
    }
}
