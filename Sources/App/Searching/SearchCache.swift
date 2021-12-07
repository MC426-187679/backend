import Foundation
import Vapor

extension Application {
    /// SearchCache padrão da aplicação.
    var searchCache: SearchCache {
        SearchCache(app: self)
    }
}

struct SearchCache {
    // MARK: - Configuração

    /// Configuração global do `SearchCache`.
    struct Configuration {
        /// Se o escore deve ser enviado na resposta do servidor.
        public var sendScore = false
        /// Se os campos escondidos devem ser enviados mesmo assim.
        public var sendHiddenFields = false
        /// Escore de corte no resultado da busca.
        public var maxResultScore = 0.99

        /// Singleton que mantém a config global.
        public static var global = Configuration()
    }

    /// A aplicação que está usando o `WebScraper`.
    private let app: Application
    /// Logger da aplciação, exportado para uso durante o scraping.
    @inlinable
    var logger: Logger {
        self.app.logger
    }
    /// Configuração global do `WebScraper`.
    @inlinable
    var configuration: Configuration {
        get { Configuration.global }
        nonmutating set { Configuration.global = newValue }
    }

    /// Incializa `SearchCache` para a aplicação.
    fileprivate init(app: Application) {
        self.app = app
    }

    // MARK: - Acesso do cache.

    /// Cache para acesso do cache específico de um tipo.
    private enum CacheKey<Item: Searchable>: StorageKey, LockKey {
        typealias Value = ItemCache<Item>
    }

    /// Sobreescreve valoresno cache de um ``Searchable``.
    ///
    /// - parameter type: Tipo do cache específico.
    /// - parameter values: Novos valores pro cache.
    /// - attention: Erros são enviados para o logger.
    func overwriteCache<Item: Searchable>(of type: Item.Type = Item.self, with values: [Item]) {
        let metadata: Logger.Metadata = ["content": "\(Item.self)", "service": "\(Self.self)"]
        self.logger.info("Building new search cache.", metadata: metadata)

        do {
            let (elapsed, cache) = try withTiming { try ItemCache(values) }
            // importante o locking, pois o cache pode ser modificado durante a execução do servidor
            self.app.locks.lock(for: CacheKey<Item>.self).withLock {
                self.app.storage[CacheKey<Item>.self] = cache
            }

            self.logger.info("Search cache built in \(elapsed) secs.", metadata: metadata)
        } catch {
            self.logger.info("Failure while building search cache.", metadata: metadata)
        }
    }

    /// Faz a busca em cache especifico.
    ///
    /// - parameter type: Tipo específico do cache. Resultados da busca seguem o padrão desse tipo.
    /// - parameter query: Texto da busca.
    /// - returns: Lista de resultados, ordenado por score.
    /// - attention: Retorna vetor vazio se o cache não estiver inicializado.
    @inlinable
    func search<Item: Searchable>(on type: Item.Type, for query: String) -> [SearchResult] {
        // importante o locking, pois o cache pode ser modificado durante a execução do servidor
        let cache = self.app.locks.lock(for: CacheKey<Item>.self).withLock {
            self.app.storage[CacheKey<Item>.self]
        }
        return cache?.search(for: query) ?? []
    }
}

/// Cache de um tipo procurável específico.
private struct ItemCache<Item: Searchable> {
    /// Scorer da cada dado presente no cache.
    private let scorers: [ItemScorer<Item>]

    /// Limite de corte no score dos resultados.
    @inlinable
    var maxResultScore: Double {
        SearchCache.Configuration.global.maxResultScore
    }

    /// Se os campos ocultos devem ser enviados mesmo assim.
    @inlinable
    var sendHiddenFields: Bool {
        SearchCache.Configuration.global.sendHiddenFields
    }

    /// Inicializa cache a partir de um conjunto de dados.
    init(_ values: [Item]) throws {
        self.scorers = try values.map { try ItemScorer(item: $0) }
    }

    /// Realiza a busca comparando a `query` com cada campo de cada dado.
    ///
    /// - returns: Vetor de resultados ordenado por score.
    @inlinable
    func search(for query: String) -> [SearchResult] {
        let searchQuery = query.normalized().reducingWhitespace()

        var results = self.scorers.compactMap { scorer -> SearchResult? in
            let score = scorer.score(for: searchQuery)
            if score > self.maxResultScore {
                return nil
            } else {
                let values = scorer.values(withHiddenFields: self.sendHiddenFields)
                return SearchResult(of: Item.self, fields: values, score: score)
            }
        }

        results.sort(by: { $0.score < $1.score })
        return results
    }
}

/// Resultado de busca sem informação do tipo específico.
struct SearchResult: Content {
    /// Descrição do conteúdo.
    let contentName: String
    /// Score do resultado.
    let score: Double
    /// Campos usados na busca (sem informação do tipo).
    let fields: Encodable

    /// Se o escore deve ser enviado na resposta do servidor.
    @inlinable
    var sendScore: Bool {
        SearchCache.Configuration.global.sendScore
    }

    /// Constrói resultado para um tipo específico.
    ///
    /// - parameter type: Tipo do dado.
    /// - parameter fields: Dicionário das propriedades usadas na bsuca.
    /// - parameter score: Valor usado como score do dado.
    @inlinable
    init<Item: Searchable>(of type: Item.Type, fields: [Item.Properties: String], score: Double) {
        self.contentName = Item.contentName
        self.score = score
        self.fields = FieldsWrapper<Item>(fields)
    }

    /// Wrapper sobre o dicionário de campos do tipo. Usado para tornar o resultado um tipo dinâmico.
    private struct FieldsWrapper<Item: Searchable>: Encodable {
        /// Mapeamento interno de cada propriedade e seu valor.
        let inner: [Item.Properties: String]

        @inlinable
        init(_ fields: [Item.Properties: String]) {
            self.inner = fields
        }

        @inlinable
        func encode(to encoder: Encoder) throws {
            /// usa a propriedade no encoding
            var container = encoder.container(keyedBy: Item.Properties.self)
            for (field, value) in self.inner {
                try container.encode(value, forKey: field)
            }
        }
    }
}

extension SearchResult: Codable {
    init(from decoder: Decoder) throws {
        /// nunca de ser recebido pelo servidor
        throw DecodingError.typeMismatch(
            SearchResult.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Can't decode a \(SearchResult.self)"
            )
        )
    }

    @inlinable
    func encode(to encoder: Encoder) throws {
        /// Chaves adicionais do resultado.
        enum ResultKey: CodingKey {
            case content
            case score
        }

        try self.fields.encode(to: encoder)

        var container = encoder.container(keyedBy: ResultKey.self)
        try container.encode(self.contentName, forKey: .content)
        if self.sendScore {
            try container.encode(self.score, forKey: .score)
        }
    }
}
