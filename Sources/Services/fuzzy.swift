import Foundation
import Fuzz

/// Wrapper para fazzy matching de strings usando a biblioteca
/// [RapidFuzz](https://github.com/maxbachmann/rapidfuzz-cpp).
final class FuzzyField: ScoreProvider {
    /// Struct em C++ (com interface em C).
    private var cached: FuzzCachedRatio

    /// Constrói cache de `value` para comparação com outras
    /// strings e calcula a norma do campo.
    @inlinable
    init(value: String) {
        // constroi com a API de C++
        self.cached = value.utf8CString.withUnsafeBufferPointer { ptr in
            fuzz_cached_init(ptr.baseAddress!)
        }
    }

    /// Precisa desalocar a memória em C++.
    @inlinable
    deinit {
        fuzz_cached_deinit(&self.cached)
    }

    /// Menor valor que para usar o partial ratio.
    private static let minScore = 0.01

    /// Compara a string no cache com `text`.
    ///
    /// - Returns: Score entre as strings que varia entre
    ///   0 (match perfeito) e 1 (completamente diferentes).
    @inlinable
    func score(for text: String) -> Double {
        let scoreValue = text.utf8CString.withUnsafeBufferPointer { ptr in
            fuzz_cached_ratio(self.cached, ptr.baseAddress!, ptr.count)
        }
        // se o score for grande o bastante, então retorna ele
        if scoreValue > Self.minScore + Double.ulpOfOne {
            return scoreValue.clamped(upTo: 1.0)
        }
        // senão, calcula um novo score, usando levenshtein diretamente
        let newScore = text.utf8CString.withUnsafeBufferPointer { ptr in
            fuzz_levenshtein(self.cached.buffer, self.cached.buflen, ptr.baseAddress!, ptr.count)
        }
        // garante o resultado no intervalo (ulpOfOne, minScore + ulpOfOne].
        return Double.ulpOfOne + Self.minScore * newScore.clamped(from: 0, upTo: 1.0)
    }
}
