import Foundation
import Vapor

/// Dado (struct ou classe) com campos procuráveis.
protocol Searchable {
    /// Propriedades procuráveis do tipo.
    associatedtype Properties: SearchableProperty where Properties.Item == Self

    /// Chave descritora do tipo. (padrão: nome do tipo em minúsculo)
    static var contentName: String { get }

    /// Fator de escalonamento no score total do item. (padrão: 1.0)
    ///
    /// Esse fator é aplicado como `pow(totalScore, scaling)`, de forma que um escalonamento maior aumenta a
    /// importância do dado no resultado de buscas genéricas.
    static var scaling: Double { get }

    /// Campos do dado que são usados como identificador (campos curtos).
    static var identifiers: Set<Properties> { get }

    /// Campos que têm importância na busca, mas não são enviados para o frontend.
    static var hiddenFields: Set<Properties> { get }
}

extension Searchable {
    @inlinable
    static var contentName: String {
        "\(Self.self)".lowercased()
    }

    @inlinable
    static var scaling: Double {
        1.0
    }

    @inlinable
    static var identifiers: Set<Properties> {
        []
    }

    @inlinable
    static var hiddenFields: Set<Properties> {
        []
    }

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
protocol SearchableProperty: CodingKey, CaseIterable, Hashable {
    /// Tipo do dado procurável.
    associatedtype Item

    /// Acesso da propriedade do dado.
    @inlinable
    func get(from item: Item) -> String

    /// Peso da propriedade (1.0, por padrão).
    ///
    /// Deve ser estritamente positivo.
    @inlinable
    var weight: Double { @inlinable get }
}

extension SearchableProperty {
    @inlinable
    var weight: Double { 1.0 }
}

/// Provedor de score para uma propriedade de um campo procurável.
private struct PropertyScorer<Item: Searchable> {
    /// Provedor interno, que depende da propriedade ser considerada um identificador ou não.
    private let provider: ScoreProvider
    /// Propriedade que está sendo comparada.
    let property: Item.Properties

    /// Constrói cache de comparação para uma propriedade.
    ///
    /// throws: ``NonPositiveWeightError`` se o peso do campo for negativo.
    init(for property: Item.Properties, of item: Item) throws {
        self.property = property

        if Item.identifiers.contains(self.property) {
            self.provider = FuzzyIdentifier(compareTo: property.get(from: item))
        } else {
            self.provider = FuzzyText(compareTo: property.get(from: item))
        }

        guard property.weight >= 0 else {
            throw NonPositiveWeightError(on: Item.self)
        }
    }

    /// Valor textual associado à propriedade.
    @inlinable
    var value: String {
        self.provider.cachedItem
    }

    /// Se a propriedade é considerada escondida.
    @inlinable
    var hidden: Bool {
        Item.hiddenFields.contains(self.property)
    }

    /// Peso do campo no cálculo do score.
    @inlinable
    var weight: Double {
        self.property.weight / Item.totalWeight
    }

    /// Compara a propriedade no cache com `text`, limitando o resultado para o range `1E-4 ... 1`.
    ///
    /// - returns: Score entre as strings que varia entre 0 (match perfeito) e 1 (completamente diferentes).
    @inlinable
    func score(for query: String) -> Double {
        let baseScore = self.provider.score(for: query)
        return baseScore.clamped(from: 1E-4, upTo: 1)
    }
}

/// Provedor de score para um dado procurável.
struct ItemScorer<Item: Searchable> {
    /// Cache de cada campo procurável.
    private let fields: [PropertyScorer<Item>]

    /// Constrói cache para os campos de um dado.
    init(item: Item) throws {
        self.fields = try Item.properties.map { property in
            try PropertyScorer(for: property, of: item)
        }
    }

    /// Fator de escalonamento.
    ///
    /// - see: ``Searchable.scaling``
    @inlinable
    var scaling: Double {
        abs(Item.scaling)
    }

    /// Propriedades procuráveis do dado com seus respectivos valores.
    ///
    /// parameter withHiddenFields: Decide se os campos considerados `hidden` devem ser inseridos no dicionário.
    /// - returns: Dicionário com cada propriedade e seu valor textual.
    @inlinable
    func values(withHiddenFields: Bool = false) -> [Item.Properties: String] {
        Dictionary(uniqueKeysWithValues: self.fields.compactMap { field in
            if withHiddenFields || !field.hidden {
                return (field.property, field.value)
            } else {
                return nil
            }
        })
    }

    /// Compara todas as propriedades no cache com `text` e retorna um score combinado.
    ///
    /// - returns: Score entre as strings que varia entre 0 (match perfeito) e 1 (completamente diferentes).
    @inlinable
    func score(for query: String) -> Double {
        // de https://github.com/krisk/Fuse/blob/master/src/core/computeScore.js
        let totalScore = self.fields.reduce(1.0) { (totalScore, field) in
            return totalScore * pow(field.score(for: query), field.weight)
        }
        return pow(totalScore, self.scaling)
    }
}

/// Erro para tipos `Searchable` mas com peso negativo ou zero.
struct NonPositiveWeightError: DebuggableError {
    /// Todas as propriedades do tipo defeituoso.
    private let properties: [String: Double]
    /// Tipo com problema de peso não-positivo.
    private let type: Any.Type

    /// Constrói erro para tipos buscáveis se existir alguma
    /// propriedade com peso não-positivo.
    init<Item: Searchable>(on type: Item.Type) {
        self.type = type

        self.properties = Dictionary(uniqueKeysWithValues: Item.properties.map { field in
            (name: "\(field)", field.weight)
        })
    }

    // MARK: - DebuggableError

    var identifier: String { "" }

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

    var reason: String {
        "Type '\(self.type)' with fields \(self.formattedFields) contains"
        + " \(self.offendingFields.count) negative weights"
    }
}
