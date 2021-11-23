//
//  SearchController.swift
//
//
//  Created by Erick Manaroulas Felipe on 28/10/21.
//

import Foundation
import Vapor
import Services

internal final class SearchController {

    /// Logger da aplicação, para reutilizar depois.
    private let logger: Logger = .controllerLogger
    /// Limite de busca usado quando não especificado.
    private static let defaultSearchLimit = 100
    /// Limite máximo de busca.
    static let maxSearchLimit = 1000
    static let shared = SearchController()

    private init() { }

    /// Parâmetros de busca textual.
    struct SearchParams: Content {
        let query: String
        let limit: Int?
    }

    func searchFor(_ req: Request) throws -> EventLoopFuture<[Match]> {
        let params = try req.query.decode(SearchParams.self)
        let limit = min(params.limit ?? Self.defaultSearchLimit, Self.maxSearchLimit)
        guard limit > 0 else {
            throw Abort(.badRequest)
        }

        // roda em async para não travar a aplicação
        // https://docs.vapor.codes/4.0/async/#blocking
        return req.application.async(on: req.eventLoop) {
            self.search(
                for: params.query,
                limitingTo: min(params.limit ?? Self.defaultSearchLimit, Self.maxSearchLimit),
                maxScore: 0.99
            )
        }
    }

    /// Busca textual dentre os dados carregados na memória.
    ///
    /// - Returns: Os `limit` melhores scores dentre todos os
    ///   os conjuntos de dados, mas com score menor que
    ///   `maxScore`.
    private func search(for text: String, limitingTo limit: Int, maxScore: Double) -> [Match] {
        let (elapsed, matches) = withTiming { () -> [Match] in
            let disciplinesResult = Discipline.Controller.shared.search(for: text, limitedTo: limit, upTo: maxScore)
            let coursesResult = Course.Controller.shared.search(for: text, limitedTo: limit, upTo: maxScore)
            return mergeAndSortSearchResults(results: [disciplinesResult, coursesResult], limitingTo: limit)
        }
        self.logger.info("Searched for \"\(text)\" with \(matches.count) results in \(elapsed) secs.")

        return matches
    }

    /// Junta vários resultados de busca em um só array.
    private func mergeAndSortSearchResults(results: [[Match]], limitingTo limit: Int) -> [Match] {
        var allResults = results.flatMap { $0 }
        allResults.sort { $0.score }
        return Array(allResults.prefix(limit))
    }
}
