import Foundation
import Logging

/// Dado (struct ou classe) com campos procuráveis.
public protocol Searchable {
    /// Propriedades procuráveis do tipo.
    associatedtype Properties: SearchableProperty where Properties.Of == Self
    /// Propriedade usada para ordenadação.
    ///
    /// O padrão é `nil`.
    @inlinable
    static var sortOn: Properties? {
        @inlinable get
    }
}

public extension Searchable {
    @inlinable
    static var sortOn: Properties? { nil }

    /// Coleção de propriedades do dado.
    @inlinable
    static var properties: Properties.AllCases {
        Properties.allCases
    }

    /// Soma dos pesos para normalização.
    @inlinable
    static var totalWeight: Double {
        self.properties.reduce(0) { $0 + $1.weight }
    }
}

/// Enum das propriedades procuráveis de um dado.
public protocol SearchableProperty: CaseIterable, Equatable {
    /// Tipo do dado procurável.
    associatedtype Of: Searchable

    /// Acesso da propriedade do dado.
    @inlinable
    func get(from item: Of) -> String

    /// Peso da propriedade (1.0, por padrão).
    ///
    /// Deve ser estritamente positivo.
    @inlinable
    var weight: Double { @inlinable get }
}

public extension SearchableProperty {
    @inlinable
    var weight: Double { 1.0 }
}

/// Conjunto imutável de um mesmo tipo de dados procuráveis.
public struct Database<Item: Searchable> {
    /// Campos procuráveis do dado.
    public typealias Field = Item.Properties
    /// Campo de ordenação.
    private static var sortedOn: Field? { Item.sortOn }
    /// Par struct e sua cache de fuzzy matching.
    private typealias Entry = (item: Item, cache: FuzzyCache)

    /// Conjunto de dados.
    private let entries: [Entry]

    /// Prepara os dados para busca.
    ///
    /// `Item` não deve conter pesos negativos.
    private static func buildEntries(for data: [Item]) -> [Entry] {
        /// monta cache de cada dado
        var entries = data.concurrentMap { item in
            Entry(item, FuzzyCache(for: item))
        }
        // ordena se requisitado
        if let field = Item.sortOn {
            entries.sort { field.get(from: $0.item) }
        }
        return entries
    }

    /// Constrói banco de dados na memória com cache de busca.
    public init(entries data: [Item], logger: Logger) throws {
        // garante pesos positivos
        guard Item.properties.allSatisfy({ $0.weight > 0 }) else {
            throw NonPositiveWeightError(on: Item.self)
        }
        // só então monta os dados
        logger.info("Buildind Database for \(Item.self)...")

        let (elapsed, entries) = withTiming {
            Self.buildEntries(for: data)
        }
        self.entries = entries

        logger.info("DB for \(Item.self) built with \(data.count) items in \(elapsed) secs.")
    }

    /// Busca linear no conjunto de dados.
    ///
    /// - Returns: Primeiro elemento que retorna
    ///  `true` para o predicado.
    private func find(where predicate: (Item) throws -> Bool) rethrows -> Item? {
        try self.entries.first { try predicate($0.item) }?.item
    }

    /// Busca binária no conjunto de dados.
    ///
    /// - Returns: Primeiro elemento com campo
    ///   de ordenação igual a `value`.
    private func findOnSorted(with value: String) -> Item? {
        guard let field = Self.sortedOn else {
            return nil
        }
        // busca binária no campo base da ordenação
        return self.entries.binarySearch(
            for: value,
            on: { field.get(from: $0.item) }
        // tem que garantir que o resultado é exato
        ).flatMap { (match, _) in
            if field.get(from: match) == value {
                return match
            } else {
                return nil
            }
        }
    }

    /// Busca por um dos campos do dado.
    ///
    /// - Returns: Algum elemento no conjunto de dados
    ///   com `field.getter(element) == value`.
    ///
    /// Executa busca binário quando o campo é base de ordenação
    /// (`Searchable.sortOn`) e busca linear nos outros casos.
    public func find(_ field: Field, equals value: String) -> Item? {
        switch field {
            case Self.sortedOn:
                return self.findOnSorted(with: value)
            default:
                return self.find { field.get(from: $0) == value }
        }
    }

    /// Busca textual no conjunto de dados.
    ///
    /// - Returns: Os dados com score menor que `maxScore`,
    ///   e o seu score para a string de busca.
    private func search(_ query: QueryString, upTo maxScore: Double) -> [(item: Item, score: Double)] {
        return self.entries.compactMap { (item, cache) in
            let score = cache.fullScore(for: query)

            if score < maxScore {
                return (item, score)
            } else {
                return nil
            }
        }
    }

    /// Busca textual no conjunto de dados.
    ///
    /// - Returns: Os dados com score menor que `maxScore`,
    ///   e o seu score para a string de busca.
    public func search(_ text: String, upTo maxScore: Double) -> [(item: Item, score: Double)] {
        self.search(QueryString(text), upTo: maxScore)
    }
}

/// Erro para tipos `Searchable` mas com peso negativo ou zero.
private struct NonPositiveWeightError: Error, LocalizedError {
    /// Todas as propriedades do tipo defeituoso.
    private let properties: [(name: String, weight: Double)]
    /// Tipo com problema de peso não-positivo.
    private let type: Any.Type

    /// Constrói erro para tipos buscáveis se existir alguma
    /// propriedade com peso não-positivo.
    init<T: Searchable>(on type: T.Type) {
        self.type = type

        self.properties = T.properties.map { field in
            (name: "\(field)", field.weight)
        }
    }

    /// Propriedades formatadas para impressão.
    private var formattedFields: [String] {
        self.properties.map { (name, weight) in
            "\(name) (\(weight))"
        }
    }

    /// Propriedades com peso não-positivo.
    private var offendingFields: [String] {
        self.properties.compactMap { (name, weight) in
            if weight <= 0 {
                return name
            } else {
                return nil
            }
        }
    }

    var errorDescription: String? {
        "Searchable type '\(self.type)' contains non-positive weights."
    }

    var failureReason: String? {
        "Type '\(self.type)' with fields \(self.formattedFields) contains"
        + " \(self.offendingFields.count) negative weights"
    }

    var recoverySuggestion: String? {
        "Fix weight for fields: \(self.offendingFields.joined(separator: ", "))"
    }
}
