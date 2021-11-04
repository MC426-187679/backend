import Foundation
import Services
import Vapor

extension Discipline {
    /// Controlador das disciplinas recuperadas por Scraping.
    ///
    /// Classe singleton. Usar `.shared` para pegar instância.
    final class Controller: ContentController<Discipline> {

        /// Instância compartilhada do singleton.
        ///
        /// Por ser estática, é lazy por padrão, ou seja,
        /// o database será criado apenas na primeira chamada.
        static let shared = try! Controller()
        
        /// Inicializador privado do singleton.
        private init() throws {
            let data = try Discipline.scrape(logger: .controllerLogger)
            try super.init(entries: data.flatMap { $1 }, logger: .controllerLogger)
        }
        
        /// Busca apenas entre as disciplinas
        func fetchDiscipline(_ req: Request) throws -> Discipline {
            try fetchContent(on: .code, req)
        }
    }
    
}
