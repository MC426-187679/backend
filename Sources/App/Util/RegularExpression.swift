import Foundation

/// Wrapper sobre ``NSRegularExpression``.
struct RegularExpression {
    private let regex: NSRegularExpression

    /// Padrão usado na expressão regular.
    var pattern: String {
        self.regex.pattern
    }

    /// Tenta inicializar a regex parseando o padrão.
    init(pattern: String) throws {
        self.regex = try NSRegularExpression(pattern: pattern)
    }

    /// Todas as regiões de match em `text`.
    func matches(in text: String) -> [Match] {
        let matchRange = NSRange(location: 0, length: text.utf16.count)
        let results = self.regex.matches(in: text, range: matchRange)

        return results.compactMap { result in Match(result, in: text) }
    }

    /// Apenas a primeira região de match em `text`.
    func firstMatch(in text: String) -> Match? {
        let matchRange = NSRange(location: 0, length: text.utf16.count)
        let result = self.regex.firstMatch(in: text, range: matchRange)

        return result.flatMap { result in Match(result, in: text) }
    }

    /// Um resultado da regex em uma string.
    struct Match {
        /// Texto que foi buscado.
        let inputText: String
        /// Região que ocorreu o match do padrão em `inputText`.
        let range: Range<String.Index>
        /// Grupos de matchs específicos dentro da match principal.
        let groupsRanges: [Range<String.Index>]

        /// Inicializa a partir do resultados de ``NSRegularExpression``.
        ///
        /// Não deveria retornar `nil`.
        fileprivate init?(_ result: NSTextCheckingResult, in text: String) {
            guard let range = Range(result.range, in: text) else {
                return nil
            }
            self.inputText = text
            self.range = range

            var groups: [Range<String.Index>] = []
            // o primeiro range é o mesmo que `result.range`
            for index in 1 ..< result.numberOfRanges {
                // não deveria dar `nil` nunca
                if let range = Range(result.range(at: index), in: text) {
                    groups.append(range)
                }
            }
            self.groupsRanges = groups
        }

        /// Parte de `inputText` que deu match com o padrão.
        var text: Substring {
            self.inputText[self.range]
        }

        /// Grupos de matchs específicos dentro da match principal.
        var groups: [Substring] {
            self.groupsRanges.map { range in
                self.inputText[range]
            }
        }
    }
}
