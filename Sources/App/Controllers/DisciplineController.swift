import Foundation
import Services
import Vapor

extension Discipline {
    /// Controlador das disciplinas recuperadas por Scraping.
    struct Controller: ContentController {
        typealias Content = Discipline

        private let db: Database<Discipline>

        init(logger: Logger? = nil) throws {
            let data = try Discipline.scrape(logger: logger)
            self.db = try Database(entries: data.flatMap { $1 }, logger: logger)
        }

        /// Recupera disciplina por código.
        func get(code: String) -> Discipline? {
            self.db.find(.code, equals: code)
        }

        /// Busca apenas entre as disciplinas.
        func search(for text: String, upTo maxScore: Double) -> [(item: Discipline, score: Double)] {
            self.db.search(text, upTo: maxScore)
        }
    }
}
