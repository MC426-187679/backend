import Foundation
import Vapor

/// Representação de um curso.
struct Course: Content, Hashable, Sendable {
    /// Código do curso.
    let code: String
    /// Nome do curso.
    let name: String
    /// Modalidades, se houver, ou a árvore do curso.
    let curriculum: Curriculum

    /// Uma árvore de uma modalidade de um curso.
    typealias Tree = [Semester]

    /// Um semestre no currículo de um curso.
    struct Semester: Content, Hashable {
        /// Disciplinas no semestre, com código e créditos.
        let disciplines: ArraySet<DisciplinePreview>
        /// Quantidade de créditos eletivos no semestre.
        let electives: UInt

        /// Disciplina representada por seu código e quantidade de créditos.
        struct DisciplinePreview: Hashable, Content, Comparable {
            let code: String
            let credits: UInt

            func hash(into hasher: inout Hasher) {
                // só o código deve importar no hash
                hasher.combine(self.code)
            }

            static func < (_ first: Self, _ second: Self) -> Bool {
                first.code < second.code
            }
        }

        /// Total de créditos em disciplinas obrigatórias.
        @inlinable
        var requiredCredits: UInt {
            self.disciplines.reduce(0) { $0 + $1.credits }
        }

        /// Total de cŕeditos.
        @inlinable
        var credits: UInt {
            self.requiredCredits + self.electives
        }
    }

    /// Representa uma modalidade de um curso.
    struct Variant: Content, Hashable {
        /// Nome da modalidade.
        let name: String
        // Código da modalidade (nem todas têm).
        let code: String
        /// Árvore da modalidade.
        let tree: Tree
    }

    /// Representa as modalidades ou a árvore do curso.
    enum Curriculum: Content, Hashable {
        /// Caso em que há modalidades.
        case variants([Variant])
        /// Caso em que não há modalidades.
        case tree(Tree)
    }

    /// Nome das modalidades no currículo.
    @inlinable
    var variants: [Variant] {
        switch self.curriculum {
            case .variants(let variants):
                return variants
            case .tree:
                return []
        }
    }

    /// Árvores para cada modalidade no currículo.
    @inlinable
    var trees: [String: Tree] {
        switch self.curriculum {
            case .variants(let variants):
                let pairs = variants.enumerated().flatMap { index, variant in
                    [
                        (variant.code, variant.tree),
                        ("\(index)", variant.tree)
                    ]
                }
                return Dictionary(uniqueKeysWithValues: pairs)
            case .tree(let tree):
                return ["arvore": tree, "0": tree]
        }
    }
}

extension Course: Searchable {
    static let scaling = 0.8
    static let identifiers: Set<Properties> = [.code]

    /// Propriedades buscáveis no curso.
    enum Properties: SearchableProperty {
        /// Busca por código.
        case code
        /// Busca por nome.
        case name

        @inlinable
        func get(from item: Course) -> String {
            switch self {
                case .code:
                    return item.code
                case .name:
                    return item.name
            }
        }
        @inlinable
        var weight: Double {
            switch self {
                case .code:
                    return 0.2
                case .name:
                    return 0.8
            }
        }
    }
}
