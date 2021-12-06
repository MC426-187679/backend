import Foundation
import Vapor

/// Conjuto ordenado de elementos distintos.
struct ArraySet<Element: Hashable & Comparable & Codable & Sendable>: Hashable, Sendable {
    private let values: [Element]

    /// Contrói conjunto a partir de valores não ordenados.
    init(_ valueSet: Set<Element>) {
        var values = Array(valueSet)
        values.sort()
        self.values = values
    }

    /// Contrói conjunto a partir de valores não ordenados e possivelmente repetidos.
    init(uniqueValues values: [Element]) {
        self.init(Set(values))
    }
}

extension ArraySet: Sequence {
    func makeIterator() -> IndexingIterator<[Element]> {
        self.values.makeIterator()
    }
}

extension ArraySet: Comparable {
    static func < (_ first: Self, _ second: Self) -> Bool {
        var (first, second) = (first.makeIterator(), second.makeIterator())

        while true {
            switch (first.next(), second.next()) {
                case (.some(let value), .some(let other)):
                    if value != other {
                        return value < other
                    }
                case (nil, .some):
                    return true
                default:
                    return false
            }
        }
    }
}

extension ArraySet: Content {
    init(from decoder: Decoder) throws {
        self.init(uniqueValues: try Array(from: decoder))
    }

    func encode(to encoder: Encoder) throws {
        try self.values.encode(to: encoder)
    }
}

extension ArraySet: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Element...) {
        self.init(uniqueValues: elements)
    }
}
