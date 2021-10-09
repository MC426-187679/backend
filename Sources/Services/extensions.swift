import Foundation

public extension Collection {
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
    func get(at position: Index) -> Element? {
        if self.indices.contains(position) {
            return self[position]
        } else {
            return nil
        }
    }
}

/// Mutex que cobre um valor.
///
/// # Obsercação
///
/// Não é seguro em usos gerais.
private class Mutex<T> {
    private let inner = NSLock()
    private var value: T

    init(_ value: T) {
        self.value = value
    }

    /// Executa uma ação com controle da mutex.
    func withLock<U>(perform: (inout T) throws -> U) rethrows -> U {
        self.inner.lock()
        defer { self.inner.unlock() }

        return try perform(&self.value)
    }

    /// Acessa o valor, sem trancar a mutex.
    ///
    /// # Cuidado
    ///
    /// Usar apenas após todas as operações com a mutex.
    func get() -> T {
        self.value
    }
}

public extension RandomAccessCollection where SubSequence == ArraySlice<Element> {
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
            let err = Mutex<Error?>(nil)

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

            if let error = err.get() {
                try onError(error)
            }
        }
    }

    /// Versão concorrente do ``Array.map``.
    ///
    /// O resultado pode ter uma ordem diferente da esperada.
    func concurrentMap<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        let transformed = Mutex<[T]>([])

        try self.concurrentForEach { item in
            let newItem = try transform(item)

            transformed.withLock {
                $0.append(newItem)
            }
        }
        return transformed.get()
    }

    /// Versão concorrente do ``Array.flatMap``.
    ///
    /// O resultado pode ter uma ordem diferente da esperada.
    func concurrentFlatMap<Segment: Sequence>(
        _ transform: (Element) throws -> Segment
    ) rethrows -> [Segment.Element] {
        let transformed = Mutex<[Segment.Element]>([])

        try self.concurrentForEach { item in
            let newSequence = try transform(item)

            transformed.withLock {
                $0.append(contentsOf: newSequence)
            }
        }
        return transformed.get()
    }

    /// Versão concorrente do ``Array.compactMap``.
    ///
    /// O resultado pode ter uma ordem diferente da esperada.
    func concurrentCompactMap<Result>(
        _ transform: (Element) throws -> Result?
    ) rethrows -> [Result] {
        let transformed = Mutex<[Result]>([])

        try self.concurrentForEach { item in
            if let newItem = try transform(item) {
                transformed.withLock {
                    $0.append(newItem)
                }
            }
        }
        return transformed.get()
    }
}

public extension MutableCollection where Self: RandomAccessCollection {
    /// Ordena a coleção usando uma chave de comparação.
    ///
    /// - Complexity: O(*n* log *n*)
    mutating func sort<T: Comparable>(on key: (Element) throws -> T) rethrows {
        try self.sort { try key($0) < key($1) }
    }
}

public extension RandomAccessCollection where Index: BinaryInteger {
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
    func binarySearch<T: Comparable>(
        for searchKey: T,
        on key: (Element) throws -> T
    ) rethrows -> Element? {
        try self.binarySearch(for: searchKey, on: key, by: <)
    }
}

/// Localização POSIX para remoção de acentos.
private let usPosixLocale = Locale(identifier: "en_US_POSIX")

public extension StringProtocol {
    /// Remove a extensão do nome do arquivo.
    ///
    /// ```swift
    /// "arquivo.py".strippedExtension() == "arquivo"
    /// ```
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
            locale: usPosixLocale
        )
    }
}
