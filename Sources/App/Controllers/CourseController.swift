import Foundation
import Vapor

extension Application {
    /// Instância compartilhada do singleton.
    var courses: Course.Controller {
        get async throws {
            try await self.instance(controller: Course.Controller.self)
        }
    }
}

extension Request {
    /// Instância compartilhada do singleton.
    var courses: Course.Controller {
        get async throws {
            try await self.application.courses
        }
    }
}

extension Course {
    /// Controlador dos cursos recuperados por Scraping.
    ///
    /// Classe singleton. Usar `app.courses` para pegar instância.
    struct Controller: ContentController {
        private let courses: [String: Course]

        /// Inicializador privado do singleton.
        init(content: [Course]) {
            self.courses = Dictionary(uniqueKeysWithValues: content.map { course in
                (code: course.code, course)
            })
        }

        /// Recupera curso por código.
        func fetchCourse(code: String) throws -> Course.Preview {
            guard let course = self.courses[code] else {
                throw Abort(.notFound)
            }

            return Preview(code: course.code, name: course.name, variants: course.variantNames)
        }

        /// Recupera árvore por código e índice.
        func fetchCourseTree(code: String, variant: String) throws -> Course.Tree {
            guard let index = Int(variant) else {
                throw Abort(.badRequest)
            }
            guard
                let course = self.courses[code],
                let tree = course.trees.get(at: index)
            else {
                throw Abort(.notFound)
            }

            return tree
        }
    }

    /// Resumo do curso, sem as árvores.
    struct Preview: Content {
        let code: String
        let name: String
        let variants: [String]
    }
}
