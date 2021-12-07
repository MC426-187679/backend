//
//  SearchController.swift
//
//
//  Created by Erick Manaroulas Felipe on 28/10/21.
//

import Foundation
import Vapor

extension Application {
    /// Instância compartilhada do singleton.
    var searchController: SearchController {
        SearchController(app: self)
    }
}

extension Request {
    /// Instância compartilhada do singleton.
    var searchController: SearchController {
        self.application.searchController
    }
}

/// Parâmetros de busca textual.
struct SearchParams: Content {
    let query: String
    let limit: UInt?

    static var configuration: SearchController.Configuration {
        get { SearchController.Configuration.global }
        set { SearchController.Configuration.global = newValue }
    }

    /// Limite de busca usado quando não especificado.
    var defaultSearchLimit: UInt {
        Self.configuration.defaultSearchLimit
    }
    /// Limite máximo de busca.
    var maxSearchLimit: UInt {
        Self.configuration.maxSearchLimit
    }

    /// Limite a ser usado na busca.
    var searchLimit: Int {
        let limit = min(self.limit ?? self.defaultSearchLimit, self.maxSearchLimit)
        return Int(clamping: limit)
    }
}

struct SearchController {
    // MARK: - Configurações.

    /// Configuração global do `SearchController`.
    struct Configuration {
        /// Limite de busca usado quando não especificado.
        let defaultSearchLimit: UInt = 25
        /// Limite máximo de busca. Note que o limite é 'soft' e não produz erros.
        let maxSearchLimit: UInt = 100

        /// Singleton que mantém a config global.
        public static var global = Configuration()
    }

    /// Configuração global do `SearchController`.
    @inlinable
    var configuration: Configuration {
        get { Configuration.global }
        nonmutating set { Configuration.global = newValue }
    }

    private let app: Application

    /// Incializa `SearchController` para a aplicação.
    fileprivate init(app: Application) {
        self.app = app
    }

    func searchFor(params: SearchParams) async -> [SearchResult] {
        let (query, limit) = (params.query, params.searchLimit)

        return await withTaskGroup(of: [SearchResult].self) { group in
            group.addTask { self.app.searchCache.search(on: Discipline.self, for: query) }
            group.addTask { self.app.searchCache.search(on: Course.self, for: query) }

            return await self.mergeAndSortSearchResults(group, limitingTo: limit)
        }
    }

    /// Junta vários resultados de busca em um só array.
    private func mergeAndSortSearchResults(
        _ resultGroup: TaskGroup<[SearchResult]>,
        limitingTo limit: Int
    ) async -> [SearchResult] {

        var globalResults: ArraySlice<SearchResult> = []
        for await results in resultGroup {
            globalResults.append(contentsOf: results.prefix(limit))
            globalResults.sort(by: { $0.score < $1.score })
            globalResults = globalResults.prefix(limit)
        }
        return Array(globalResults)
    }
}
