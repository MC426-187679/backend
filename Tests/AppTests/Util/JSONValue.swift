import Foundation
import XCTest

/// Checa se `text` representa o mesmo objeto que `matches` em JSON.
func XCTAssertJSON(
    text: @autoclosure () throws -> String,
    matches value: @autoclosure () throws -> JSONValue,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file,
    line: UInt = #line
) {
    XCTAssertJSONEqual(
        JSONValue(fromJson: try text()) ?? .null,
        try value(),
        message(),
        file: file,
        line: line
    )
}

/// Checa dois valores de JSON, comparando cada subelemento por vez.
func XCTAssertJSONEqual(
    _ first: @autoclosure () throws -> JSONValue,
    _ second: @autoclosure () throws -> JSONValue,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file,
    line: UInt = #line
) {
    let first = Result { try first() }
    let second = Result { try second() }
    XCTAssertNoThrow(try first.get(), message(), file: file, line: line)
    XCTAssertNoThrow(try second.get(), message(), file: file, line: line)

    switch (try? first.get(), try? second.get()) {
        case (.object(let first), .object(var second)):
            for (key, value) in first {
                let other = second.removeValue(forKey: key) ?? .null
                XCTAssertJSONEqual(value, other, message(), file: file, line: line)
            }
            XCTAssertEqual(second, [:])
        case (.array(let first), .array(var second)):
            for value in first {
                let other = second.isEmpty ? .null : second.removeFirst()
                XCTAssertJSONEqual(value, other, message(), file: file, line: line)
            }
            XCTAssertEqual(second, [])
        case (.number(let first), .number(let second)):
            XCTAssertEqual(first, second, message(), file: file, line: line)
        case (.string(let first), .string(let second)):
            XCTAssertEqual(first, second, message(), file: file, line: line)
        case (.boolean(let first), .boolean(let second)):
            XCTAssertEqual(first, second, message(), file: file, line: line)
        case (let first, let second):
            XCTAssertEqual(first, second, message(), file: file, line: line)
    }
}

/// Um valor que segue um dos tipos básicos em JSON.
///
/// @see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON
enum JSONValue: Equatable, Hashable {
    // MARK: - Valores de JSON.

    /// Um objeto que relaciona chaves à valores.
    case object([String: JSONValue])
    /// Um vetor de valores genéricos.
    case array([JSONValue])
    /// Um número, inteiro ou ponto flutuante.
    case number(Double)
    /// Uma string do JSON.
    case string(String)
    /// Um booleano de JSON.
    case boolean(Bool)
    /// Um valor nulo de JSON.
    case null

    // MARK: - Usando representação textual de JSON.

    /// Decoder para transformação textual.
    private static let decoder = JSONDecoder()
    /// Encoder para transformação textual.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting.formUnion(.prettyPrinted)
        return encoder
    }()

    /// Gera valor a partir de um texto válido em JSON.
    init?(fromJson string: String) {
        guard
            let data =  string.data(using: .utf8),
            let value = try? Self.decoder.decode(Self.self, from: data)
        else {
            return nil
        }
        self = value
    }

    /// Tenta gerar um valor a partir de um objeto encódavel para JSON.
    init<Value: Encodable>(fromDecodable value: Value) throws {
        let data = try Self.encoder.encode(value)
        self = try Self.decoder.decode(Self.self, from: data)
    }

    /// Representação em JSON do valor.
    func asJsonString() -> String? {
        if let encoded = try? Self.encoder.encode(self) {
            return String(data: encoded, encoding: .utf8)
        } else {
            return nil
        }
    }

    // MARK: - Representação com tipos básicos de Swift.

    /// Inicializa com um valor convertível para JSON.
    init(fromValue value: JSONConvertible) {
        self = value.toJsonValue()
    }

    /// Inicializa com `null`.
    init() {
        self = .null
    }

    /// Retorna um dicionário se o valor for um objeto.
    func asObject() -> [String: JSONValue]? {
        if case .object(let value) = self {
            return value
        } else {
            return nil
        }
    }

    /// Retorna um vetor se o valor for um vetor.
    func asArray() -> [JSONValue]? {
        if case .array(let value) = self {
            return value
        } else {
            return nil
        }
    }

    /// Retorna um double se o valor for um número.
    func asNumber() -> Double? {
        if case .number(let value) = self {
            return value
        } else {
            return nil
        }
    }

    /// Retorna uma string se o valor for uma string.
    func asString() -> String? {
        if case .string(let value) = self {
            return value
        } else {
            return nil
        }
    }

    /// Retorna um booleano se o valor for um booleano.
    func asBoolean() -> Bool? {
        if case .boolean(let value) = self {
            return value
        } else {
            return nil
        }
    }

    /// Retorna se o valor é nulo.
    func isNull() -> Bool {
        self == .null
    }
}

extension JSONValue: CustomStringConvertible {
    var description: String {
        self.asJsonString() ?? "Invalid JSONValue"
    }
}

extension JSONValue: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
            case .object(let value):
                return "object(\(value))"
            case .array(let value):
                return "array(\(value))"
            case .number(let value):
                return "number(\(value))"
            case .string(let value):
                return "string(\(value))"
            case .boolean(let value):
                return "boolean(\(value))"
            case .null:
                return "null"
            default:
                return "Invalid JSONValue"
        }
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: JSONValue...) {
        self = .array(Array(elements))
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByExtendedGraphemeClusterLiteral {
    init(extendedGraphemeClusterLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByUnicodeScalarLiteral {
    init(unicodeScalarLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: BooleanLiteralType) {
        self = .boolean(value)
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    init(nilLiteral: ()) {
        self = .null
    }
}

extension JSONValue: Encodable {
    func encode(to encoder: Encoder) throws {
        switch self {
            case .object(let value):
                try value.encode(to: encoder)
            case .array(let value):
                try value.encode(to: encoder)
            case .number(let value):
                try value.encode(to: encoder)
            case .string(let value):
                try value.encode(to: encoder)
            case .boolean(let value):
                try value.encode(to: encoder)
            case .null:
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            default:
                throw EncodingError.invalidValue(self, .init(
                    codingPath: encoder.codingPath,
                    debugDescription: "Invalid JSONValue"
                ))
        }
    }
}

extension JSONValue: Decodable {
    /// Implementação real do protocolo `Decodable`.
    private static func from(_ decoder: Decoder) throws -> Self {
        // a ordem talvez seja importante aqui
        if let value = try? [String: JSONValue](from: decoder) {
            return .object(value)
        }
        if let value = try? [JSONValue](from: decoder) {
            return .array(value)
        }
        if let value = try? Bool(from: decoder) {
            return .boolean(value)
        }
        if let value = try? Double(from: decoder) {
            return .number(value)
        }
        if let container = try? decoder.singleValueContainer() {
            if container.decodeNil() {
                return .null
            }
        }
        if let value = try? String(from: decoder) {
            return .string(value)
        }

        throw DecodingError.typeMismatch(JSONValue.self, .init(
            codingPath: decoder.codingPath,
            debugDescription: "Value could not be interpreted as JSONValue"
        ))
    }

    init(from decoder: Decoder) throws {
        self = try .from(decoder)
    }
}

/// Valores que podem ser convertidos para JSON sem chance de erro.
protocol JSONConvertible {
    /// Transforma em um valor de JSON.
    func toJsonValue() -> JSONValue
}

extension JSONValue: JSONConvertible {
    func toJsonValue() -> JSONValue {
        self
    }
}

extension JSONConvertible where Self: StringProtocol {
    func toJsonValue() -> JSONValue {
        .string(String(self))
    }
}

extension JSONConvertible where Self: BinaryInteger {
    func toJsonValue() -> JSONValue {
        .number(Double(self))
    }
}

extension JSONConvertible where Self: BinaryFloatingPoint {
    func toJsonValue() -> JSONValue {
        .number(Double(self))
    }
}

extension Bool: JSONConvertible {
    func toJsonValue() -> JSONValue {
        .boolean(self)
    }
}

extension JSONConvertible where Self: Sequence, Self.Element: JSONConvertible {
    func toJsonValue() -> JSONValue {
        .array(self.map { $0.toJsonValue() })
    }
}

extension Dictionary: JSONConvertible where Key: StringProtocol, Value: JSONConvertible {
    func toJsonValue() -> JSONValue {
        .object(.init(uniqueKeysWithValues: self.map {
            (String($0), $1.toJsonValue())
        }))
    }
}

extension Optional: JSONConvertible where Wrapped: JSONConvertible {
    func toJsonValue() -> JSONValue {
        if let value = self {
            return value.toJsonValue()
        } else {
            return .null
        }
    }
}
