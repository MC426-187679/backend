import Foundation
import Services
import Vapor

extension Course {
    /// Controlador dos cursos recuperados por Scraping.
    struct Controller: ContentController {
        typealias Content = Course

        private let db: Database<Course>

        init(logger: Logger) throws {
            let data = try Course.scrape(logger: logger)
            self.db = try Database(entries: Array(data.values), logger: logger)
        }

        /// Recupera curso por código.
        func get(code: String) -> Course? {
            self.db.find(.code, equals: code)
        }

        /// Busca apenas entre os cursos.
        func search(for text: String, upTo maxScore: Double) -> [(item: Course, score: Double)] {
            self.db.search(text, upTo: maxScore)
        }
    }
}
