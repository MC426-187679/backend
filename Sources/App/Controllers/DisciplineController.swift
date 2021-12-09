import Foundation
import Vapor

extension Application {
    /// Instância compartilhada do singleton.
    var disciplines: Discipline.Controller {
        get async throws {
            try await self.instance(controller: Discipline.Controller.self)
        }
    }
}

extension Request {
    /// Instância compartilhada do singleton.
    var disciplines: Discipline.Controller {
        get async throws {
            try await self.application.disciplines
        }
    }
}

extension Discipline {
    /// Controlador das disciplinas recuperadas por Scraping.
    ///
    /// Classe singleton. Usar `app.disciplines` para pegar instância.
    struct Controller: ContentController {
        private let disciplines: [String: Discipline]

        /// Inicializador privado do singleton.
        init(content: [Discipline]) {
            self.disciplines = Dictionary(uniqueKeysWithValues: content.map { discipline in
                (code: discipline.code, discipline)
            })
        }

        /// Busca apenas entre as disciplinas
        func fetchDiscipline(code: String) throws -> Discipline {
            guard let discipline = self.disciplines[code] else {
                throw Abort(.notFound)
            }
            return discipline
        }
    }
}
