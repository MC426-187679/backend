import Foundation
import RapidFuzz

/// Um provedor de score capaz de recuperar a string interna de comparação.
protocol ScoreProvider {
    /// Texto original recebido pelo provedor.
    var cachedItem: String { get }

    /// Compara a string no cache com `text`.
    ///
    /// - returns: Score entre as strings que varia entre 0 (match perfeito) e 1 (completamente diferentes).
    func score(for query: String) -> Double
}

/// Wrapper para fuzzy matching de texto longo usando a biblioteca
/// [RapidFuzz](https://github.com/maxbachmann/rapidfuzz-cpp).
final class FuzzyText: ScoreProvider {
    /// Struct em C++ (com interface em C).
    private var cache: RapidFuzzCachedRatio

    let cachedItem: String

    /// Constrói cache de `text` para comparação com outras strings.
    @inlinable
    init(compareTo text: String) {
        self.cachedItem = text
        // constroi com a API de C++
        let normalizedText = text.normalized().reducingWhitespace()
        self.cache = normalizedText.utf8CString.withUnsafeBufferPointer { ptr in
            rapidfuzz_cached_init(ptr.baseAddress!)
        }
    }

    /// Precisa desalocar a memória em C++.
    @inlinable
    deinit {
        rapidfuzz_cached_deinit(&self.cache)
    }

    @inlinable
    func score(for text: String) -> Double {
        text.utf8CString.withUnsafeBufferPointer { ptr in
            rapidfuzz_cached_ratio(self.cache, ptr.baseAddress!, ptr.count)
        }
    }
}

/// Wrapper para fuzzy matching de texto curto usando a biblioteca
/// [RapidFuzz](https://github.com/maxbachmann/rapidfuzz-cpp).
struct FuzzyIdentifier: ScoreProvider {
    /// Buffer para comunicação direta com C/C++.
    private let buffer: ContiguousArray<CChar>

    let cachedItem: String

    /// Constrói cache de `text` para comparação com outras strings.
    @inlinable
    init(compareTo text: String) {
        self.cachedItem = text
        self.buffer = text.normalized().reducingWhitespace().utf8CString
    }

    @inlinable
    func score(for text: String) -> Double {
        self.buffer.withUnsafeBufferPointer { str1 in
            text.utf8CString.withUnsafeBufferPointer { str2 in
                rapidfuzz_levenshtein(str1.baseAddress!, str1.count, str2.baseAddress!, str2.count)
            }
        }
    }
}
