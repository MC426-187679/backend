import Foundation

/// Dado com campos procuráveis.
public protocol Searchable {
    /// Propriedades procuráveis do tipo.
    associatedtype Properties: SearchableProperty where Properties.Of == Self
    /// Propriedade usada para ordenadação.
    ///
    /// O padrão é `nil`.
    static var sortOn: Properties? { get }
}

public extension Searchable {
    static var sortOn: Properties? { nil }
}

/// Enum das propriedades procuráveis de um dado.
public protocol SearchableProperty: CaseIterable, Equatable {
    /// Tipo do dado procurável.
    associatedtype Of: Searchable

    /// Acesso da propriedade do dado.
    func getter(_ item: Of) -> String
}

/// Conjunto imutável de um mesmo tipo de dados procuráveis.
public class Database<Entry: Searchable> {
    /// Campos procuráveis do dado.
    public typealias Field = Entry.Properties
    /// Campo de ordenação.
    static var sortedOn: Field? { Entry.sortOn }

    /// Conjunto de dados.
    private let entries: [Entry]

    /// Prepara os dados para busca.
    public init(entries data: [Entry]) {
        var entries = data
        if let field = Entry.sortOn {
            entries.sort(on: field.getter)
        }

        self.entries = entries
    }

    /// Busca linear no conjunto de dados.
    ///
    /// - Returns: Primeiro elemento no conjunto de dados
    ///   que retorna `true` para o predicado.
    public func find(where predicate: (Entry) throws -> Bool) rethrows -> Entry? {
        try entries.first(where: predicate)
    }

    /// Busca por um dos campos do dado.
    ///
    /// - Returns: Algum elemento no conjunto de dados
    ///   com `field.getter(element) == value`.
    ///
    /// Executa busca binário quando o campo é base de ordenação
    /// (`Searchable.sortOn`) e busca linear nos outros casos.
    public func find(_ field: Field, equals value: String) -> Entry? {
        if field == Self.sortedOn {
            return entries.binarySearch(for: value, on: field.getter)
                .flatMap { result in
                    // garante que o elemento tem chave certa
                    if field.getter(result) == value {
                        return result
                    } else {
                        return nil
                    }
                }
        } else {
            return entries.first { field.getter($0) == value }
        }
    }
}
