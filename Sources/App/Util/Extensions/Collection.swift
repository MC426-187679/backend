//
//  File.swift
//
//
//  Created by Vitor Jundi Moriya on 25/10/21.
//

import Foundation

extension Collection {
    /// Acesso opcional na coleção para posições que podem
    /// ser inválidas.
    ///
    /// - Returns: `nil` quando a posição requisitada
    ///   não contém um elemento associado.
    ///
    /// ```swift
    /// ["a", "b", "c"].get(at: 1) == "b"
    ///
    /// ["a", "b"].get(at: 2) == nil
    /// ```
    @inlinable
    func get(at position: Index) -> Element? {
        if self.indices.contains(position) {
            return self[position]
        } else {
            return nil
        }
    }
}

extension Sequence {
    /// Mapeamento assíncrono da sequência sem manter a ordem dos elementos.
    func asyncUnorderedMap<Transformed>(
        _ transform: @escaping @Sendable (Element) async throws -> Transformed
    ) async rethrows -> [Transformed] {

        try await withThrowingTaskGroup(of: Transformed.self) { group in
            // inicia cada mapeamento em sua própria task
            for element in self {
                let added = group.addTaskUnlessCancelled {
                    try await transform(element)
                }
                // para antes se a task for cancelada
                if !added {
                    break
                }
            }
            // só junta no final
            return try await group.reduce(into: []) { total, element in
                total.append(element)
            }
        }
    }

    /// Similar ao ``Sequence.map``, mas encerra o mapeamento antes se algum elemento retorna `nil`.
    ///
    /// - Returns: toda sequência mapeada ou `nil` se algum mapeamento não for possível.
    func tryMap<Transformed>(_ transform: (Element) throws -> Transformed?) rethrows -> [Transformed]? {
        var transformed: [Transformed] = []

        for element in self {
            guard let result = try transform(element) else {
                return nil
            }
            transformed.append(result)
        }
        return transformed
    }
}
