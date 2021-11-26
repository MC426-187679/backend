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

extension RandomAccessCollection {
    /// Versão concorrente do ``Array.forEach``.
    ///
    /// Pode ser executada em ordem diferente da esperada.
    func concurrentForEach(_ body: (Element) throws -> Void) rethrows {
        try concurrentPerform(execute: body, onError: { throw $0 })
        /// Função necessária para evitar problemas com `rethrows`. Veja:
        /// https://developer.apple.com/forums/thread/8002?answerId=24898022#24898022
        func concurrentPerform(
            execute: (Element) throws -> Void,
            onError: (Error) throws -> Void
        ) rethrows {
            /// precisa ser na mutex, para evitar data race
            /// mas ela só é usada realmente em caso de erro
            var err = Mutex<Error?>(nil)

            DispatchQueue.concurrentPerform(iterations: self.count) { position in
                let index = self.index(
                    self.startIndex,
                    offsetBy: position
                )

                do {
                    try execute(self[index])
                } catch {
                    err.withLock { $0 = error }
                }
            }
            // os erros só são acusados no final, sem early return
            if let error = err.get() {
                try onError(error)
            }
        }
    }

    /// Versão concorrent de ``Array.reduce`` com acesso direto
    /// para a `Mutex`.
    ///
    /// Não é seguro por conta do `Mutex.get`, que pode levar a
    /// data races.
    private func unsafeConcurrentReduce<Result>(
        into initialResult: Result,
        _ updateAccumulatingResult: (inout Mutex<Result>, Element) throws -> ()
    ) rethrows -> Result {
        /// mutex protege contra data races
        var result = Mutex(initialResult)

        try self.concurrentForEach { item in
            try updateAccumulatingResult(&result, item)
        }
        return result.get()
    }

    /// Versão concorrente do ``Array.map``.
    ///
    /// O resultado pode ter uma ordem diferente da esperada.
    func concurrentMap<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        try self.unsafeConcurrentReduce(into: []) { mutex, item in
            let newItem = try transform(item)
            // tranca apenas quando necessário
            mutex.withLock { $0.append(newItem) }
        }
    }

    /// Versão concorrente do ``Array.flatMap``.
    ///
    /// O resultado pode ter uma ordem diferente da esperada.
    func concurrentFlatMap<Segment: Sequence>(
        _ transform: (Element) throws -> Segment
    ) rethrows -> [Segment.Element] {
        try self.unsafeConcurrentReduce(into: []) { mutex, item in
            let newSegment = try transform(item)
            // tranca apenas quando necessário
            mutex.withLock { $0.append(contentsOf: newSegment) }
        }
    }

    /// Versão concorrente do ``Array.compactMap``.
    ///
    /// O resultado pode ter uma ordem diferente da esperada.
    func concurrentCompactMap<Result>(
        _ transform: (Element) throws -> Result?
    ) rethrows -> [Result] {
        try self.unsafeConcurrentReduce(into: []) { mutex, item in
            if let newItem = try transform(item) {
                // tranca apenas quando necessário
                mutex.withLock { $0.append(newItem) }
            }
        }
    }
}

extension MutableCollection where Self: RandomAccessCollection {
    /// Ordena a coleção usando uma chave de comparação.
    ///
    /// - Complexity: O(*n* log *n*)
    @inlinable
    mutating func sort<T: Comparable>(on key: (Element) throws -> T) rethrows {
        try self.sort { try key($0) < key($1) }
    }
}

extension RandomAccessCollection where Index: BinaryInteger {
    /// Busca binária em um vetor ordenado.
    ///
    /// - Parameter searchKey: Chave a ser buscada.
    /// - Parameter key: Acessor da chave em cada elemento.
    /// - Parameter areInIncreasingOrder: Predicado que diz se
    ///   um chave vem antes da outra (deve ser ordem estrita).
    ///
    /// - Returns: O valor com chave mais próxima de `searchKey`,
    ///   mais ainda menor ou igual (exceto quando todos são
    ///   maiores).
    ///
    /// - Complexity: O(*n* log *n*)
    @inlinable
    func binarySearch<T>(
        for searchKey: T,
        on key: (Element) throws -> T,
        by areInIncreasingOrder: (T, T) throws -> Bool
    ) rethrows -> Element? {
        var lo = self.startIndex
        var hi = self.index(lo, offsetBy: self.count)

        var result: Element? = nil
        while lo < hi {
            let mid = (lo + hi) / 2
            result = self[mid]
            let midKey = try key(self[mid])

            if try areInIncreasingOrder(midKey, searchKey) {
                lo = mid + 1
            } else if try areInIncreasingOrder(searchKey, midKey) {
                hi = mid
            } else {
                return result
            }
        }
        return result
    }

    /// Busca binária em um vetor ordenado.
    ///
    /// - Parameter searchKey: chave a ser buscada.
    /// - Parameter key: acessor da chave em cada elemento.
    ///
    /// - Returns: O valor com chave mais próxima de `searchKey`,
    ///   mais ainda menor ou igual (exceto quando todos são
    ///   maiores).
    ///
    /// - Complexity: O(log *n*)
    @inlinable
    func binarySearch<T: Comparable>(
        for searchKey: T,
        on key: (Element) throws -> T
    ) rethrows -> Element? {
        try self.binarySearch(for: searchKey, on: key, by: <)
    }
}

private struct Mutex<T> {
    private let inner = NSLock()
    private var value: T

    @inlinable
    init(_ value: T) {
        self.value = value
    }

    /// Executa uma ação com controle da mutex.
    @inlinable
    mutating func withLock<U>(perform: (inout T) throws -> U) rethrows -> U {
        self.inner.lock()
        defer { self.inner.unlock() }

        return try perform(&self.value)
    }

    /// Acessa o valor, sem trancar a mutex.
    ///
    /// # Cuidado
    ///
    /// Usar apenas após todas as operações com a mutex.
    @inlinable
    func get() -> T {
        self.value
    }
}
