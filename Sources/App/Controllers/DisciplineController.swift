import Foundation
import Services
import Vapor

extension Discipline {
    /// Controlador das disciplinas recuperadas por Scraping.
    ///
    /// Classe singleton. Usar `.shared` para pegar instância.
    final class Controller: ContentController {
        typealias Content = Discipline
        
        private let db: Database<Discipline>
        
        /// Instância compartilhada do singleton.
        ///
        /// Por ser estática, é lazy por padrão, ou seja,
        /// o database será criado apenas na primeira chamada.
        static let shared = try! Controller(logger: .controllerLogger)
        
        /// Inicializador privado do singleton.
        init(logger: Logger) throws {
            let data = try Discipline.scrape(logger: logger)
            self.db = try Database(entries: data.flatMap { $1 }, logger: logger)
        }
        
        /// Recupera disciplina por código.
        private func findDisciplineWith(code: String) -> Discipline? {
            self.db.find(.code, equals: code)
        }
        
        /// Busca apenas entre as disciplinas.
        func search(for text: String, upTo maxScore: Double) -> [(item: Discipline, score: Double)] {
            self.db.search(text, upTo: maxScore)
        }
        
        
        func fetchDiscipline(_ req: Request) throws -> Discipline {
            // SAFETY: o router do Vapor só deixa chegar aqui com o parâmetro
            let code = req.parameters.get("code")!
            
            if let discipline = self.findDisciplineWith(code: code){
                return discipline
                
            } else {
                throw Abort(.notFound)
            }
        }
    }
    
}
