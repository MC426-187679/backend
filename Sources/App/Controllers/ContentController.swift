//
//  File.swift
//  
//
//  Created by Vitor Jundi Moriya on 04/11/21.
//

import Foundation
import Services
import Vapor

class ContentController<Content: Matchable> {
    
    private let db: Database<Content>
    
    init(entries: [Content], logger: Logger) throws {
        self.db = try Database(entries: entries, logger: logger)
    }
    
    func search(for text: String, limitedTo matches: Int, upTo maxScore: Double) -> [Match] {
        var results = self.db.search(text, upTo: maxScore)
        results.sort(on: { $0.score })

        let contentName = Content.contentName
        return results.prefix(matches).map {
            Match($0.item.reduced(), $0.score, contentName)
        }
    }
    
    func fetchContent(on field: Content.Properties,_ req: Request) throws -> Content {

        // SAFETY: o router do Vapor só deixa chegar aqui com o parâmetro
        let text = req.parameters.get("\(field)")!
        
        if let course = self.db.find(field, equals: text) {
            return course
            
        } else {
            throw Abort(.notFound)
        }
    }
}
