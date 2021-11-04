//
//  File.swift
//
//
//  Created by Vitor Jundi Moriya on 25/10/21.
//

import Foundation

extension StringProtocol {
    /// Remove a extensão do nome do arquivo.
    ///
    /// ```swift
    /// "arquivo.py".strippedExtension() == "arquivo"
    /// ```
    @inlinable
    func strippedExtension() -> String {
        var components = self.components(separatedBy: ".")
        if components.count > 1 {
            components.removeLast()
        }
        return components.joined(separator: ".")
    }

    /// Normalização da String para comparação.
    ///
    /// Remove acentos e padroniza a String para não ter diferença
    /// entre maiúsculas e minúsculas, além de tratar problemas de
    /// representação com Unicode.
    func normalized() -> String {
        // de https://forums.swift.org/t/string-case-folding-and-normalization-apis/14663/7
        self.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            /// Localização POSIX para remoção de acentos.
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    /// Lista de palavras na string.
    ///
    /// Ignora espeços consecutivos.
    @inlinable
    func splitWords() -> [String] {
        self.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    /// Prepara para busca, normalizando e removendo
    /// espaços desnecessários.
    func prepareForSearch() -> String {
        self.normalized().splitWords().joined(separator: " ")
    }
}
