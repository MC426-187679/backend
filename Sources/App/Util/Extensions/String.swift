//
//  File.swift
//
//
//  Created by Vitor Jundi Moriya on 25/10/21.
//

import Foundation

extension StringProtocol {
    /// Retorna uma versão normalizada da String em relação a caracteres especiais.
    ///
    /// Remove acentos e padroniza a String para não ter diferença entre maiúsculas e minúsculas, além de tratar
    /// problemas de representação com Unicode.
    ///
    /// ```swift
    /// "Sempre há uma solução".normalized() == "sempre ha uma solucao"
    /// ```
    @inlinable
    func normalized() -> String {
        // de https://forums.swift.org/t/string-case-folding-and-normalization-apis/14663/7
        self.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            /// Localização POSIX para remoção de acentos.
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    /// Lista de palavras na string, ignorando espaços consecutivos.
    ///
    /// ```swift
    /// "   some    especially useful\n\ntext".splitWords() == ["some", "especially", "useful", "text"]
    /// ```
    @inlinable
    func splitWords() -> [String] {
        self.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    /// Retorna a string com espaços reduzidos entre palavras.
    ///
    /// ```swift
    /// "   some    especially useful\n\ntext".reducingWhitespace() == "some especially useful text"
    /// ```
    @inlinable
    func reducingWhitespace() -> String {
        self.splitWords()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")

    }

    /// Retorna a string com caracteres fora do range alfanumérico de ASCII trocados por `replace`.
    ///
    /// ```swift
    /// "file: /Resources.txt".replacingNonAlphaNum() == "file___Resources_txt"
    /// ```
    @inlinable
    func replacingNonAlphaNum(with replace: Character = "_") -> String {
        String(self.map { char in char.isASCIIAlphaNum ? char : replace })
    }
}

extension Character {
    /// Se esse caracter é um ASCII alfanumérico.
    ///
    /// Equivalente ao grupo `[a-zA-Z0-9]` em expressões regulares.
    @inlinable
    var isASCIIAlphaNum: Bool {
        ("a"..."z" as ClosedRange<Character>).contains(self)
        || ("A"..."Z" as ClosedRange<Character>).contains(self)
        || ("0"..."9" as ClosedRange<Character>).contains(self)
    }
}
