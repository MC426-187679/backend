import Foundation
import Services
import Vapor

extension Course {
    /// Controlador dos cursos recuperados por Scraping.
    ///
    /// Classe singleton. Usar `.shared` para pegar instância.
    final class Controller: ContentController {
        typealias Content = Course

        private let db: Database<Course>

        /// Instância compartilhada do singleton.
        ///
        /// Por ser estática, é lazy por padrão, ou seja,
        /// o database será criado apenas na primeira chamada.
        static let shared: Course.Controller = {
            let logger = Logger(label: "Course Controller Logger")
            return try! .init(logger: logger)
        }()

        /// Inicializador privado do singleton.
        private init(logger: Logger) throws {
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
