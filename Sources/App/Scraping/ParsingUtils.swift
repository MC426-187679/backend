import Foundation
import Vapor
import SwiftSoup

/// Conjunto de funções usados no parsing do `WebScrapable`.
enum ParsingUtils {
    /// Parseia um fragmento HTML em várias seções rotuladas.
    ///
    /// As seções devem seguir algo do tipo.
    ///
    /// ```html
    /// <headerTag>Rótulo da Seção</headerTag>
    /// <br/>
    /// <body>Conteúdo</body>
    /// ```
    ///
    /// E a função `extractBody` deve ser capaz de alcançar `<body>` a partir do `<headerTag>` atual.
    static func parseHTMLSections<Item>(
        _ container: Element?,
        headerTag: String,
        extractBody: (Element) throws -> Item?
    ) throws -> [String: Item] {
        guard let container = container else {
            throw ParsingError.missingElement()
        }

        return Dictionary(uniqueKeysWithValues:
            try container.getElementsByTag(headerTag).compactMap { title in
                // só os body alcançáveis são retornados
                if let paragraph = try extractBody(title) {
                    return (try title.text().reducingWhitespace(), paragraph)
                } else {
                    return nil
                }
            }
        )
    }

    /// Extrai o texto de um nó HTML.
    ///
    /// Para um elemento (`<elemento>`) o texto é o conteúdo dentro das tags. Para outros nós, é apenas as
    /// representação HTML do nó.
    ///
    /// ```swift
    /// getText(<div>texto</div>) == "texto"
    /// getText("div texto div") == "div texto div"
    /// ```
    ///
    /// - Parameter node: nó que terá texto extraído.
    /// - Parameter expectedTag: se diferente de `nil`, garante que `node.tagName() == expectedTag`.
    /// - Parameter ignoreChildren: se `false`, checa se o elemento tem algum filho antes de extrair o texto.
    /// - Returns: texto do elemento.
    static func getText(from node: Node?, expectedTag: String? = nil, ignoreChildren: Bool = false) throws -> String {
        // garante que o nó é válido, não tem filhos e tem a tag esperada
        guard let node = node else {
            throw ParsingError.missingElement()
        }
        let element = node as? Element
        if let expectedTag = expectedTag {
            // assume tag vazia para nós genéricos
            let tagName = element?.tagName() ?? ""
            guard expectedTag == tagName else {
                throw ParsingError.unexpectedElementTag(node: node, expectedTag: expectedTag)
            }
        }
        if !ignoreChildren {
            // conta apenas elementos filhos do elemento, ignorando o texto dele
            let childCount = element?.children().count ?? node.childNodeSize()
            guard childCount == 0 else {
                throw ParsingError.nodeHasChildren(node: node)
            }
        }

        // só então extrai o texto
        if let element = element {
            return try element.text().reducingWhitespace()
        } else {
            return try node.outerHtml().reducingWhitespace()
        }
    }

    /// Extrai o texto com ``getText`` e então passa para a função `parser`.
    ///
    /// - Parameter node: nó que terá texto extraído.
    /// - Parameter expectedTag: se diferente de `nil`, garante que `node.tagName() == expectedTag`.
    /// - Parameter ignoreChildren: se `false`, checa se o elemento tem algum filho antes de extrair o texto.
    /// - Parameter parser: função que faz o parsing do texto do elemento.
    /// - Returns: resultado do parsing do elemento.
    static func parseText<Result>(
        from node: Node?,
        expectedTag: String? = nil,
        ignoreChildren: Bool = false,
        with parser: (String) throws -> Result?
    ) throws -> Result {
        let text = try getText(from: node, expectedTag: expectedTag, ignoreChildren: ignoreChildren)
        guard let result = try parser(text) else {
            // SAFETY: getText acusa erro se `node` é `nil`
            throw ParsingError.unparseableText(node: node!, type: Result.self)
        }
        return result
    }

    /// Extrai o primeiro nó de uma lista de nós, garantindo que ele é o único da lista.
    static func unwrapSingleElement<Nodes: Sequence>(
        _ nodes: Nodes?
    ) throws -> Nodes.Element where Nodes.Element: Node {
        guard
            var iterator = nodes?.makeIterator(),
            let first = iterator.next()
        else {
            throw ParsingError.missingElement()
        }
        guard iterator.next() == nil else {
            throw ParsingError.sequenceHasMoreThanOneElement(nodes: Array(nodes!))
        }
        return first
    }
}

/// Errors gerados em `ParsingUtils`.
struct ParsingError: DebuggableError {
    // MARK: - Inicialização

    /// Tipo do erro.
    enum Kind {
        /// O nó HTML é vazio (`nil`).
        case missingElement
        /// O nó HTML tem uma tag diferente da esperada.
        case unexpectedElementTag(node: Node, expectedTag: String)
        /// O nó HTML tem filhos (extração de texto não funciona muito bem, nesse caso).
        case nodeHasChildren(node: Node)
        /// Texto extraído do HTML não pôde ser parseado.
        case unparseableText(node: Node, type: Any.Type)
        /// Sequência deveria ter um único nó, mas tem mais de um.
        case sequenceHasMoreThanOneElement(nodes: [Node])
    }

    /// Tipo do erro.
    let kind: Kind

    /// Inicialização geral.
    init(kind: Kind, source: ErrorSource = .capture(), stackTrace: StackTrace? = .capture()) {
        self.kind = kind
        self.source = source
        self.stackTrace = stackTrace
    }

    /// O nó HTML é vazio (`nil`).
    static func missingElement(
        source: ErrorSource = .capture(),
        stackTrace: StackTrace? = .capture()
    ) -> Self {

        ParsingError(kind: .missingElement, source: source, stackTrace: stackTrace)
    }

    /// O nó HTML tem uma tag diferente da esperada.
    static func unexpectedElementTag(
        node: Node,
        expectedTag: String,
        source: ErrorSource = .capture(),
        stackTrace: StackTrace? = .capture()
    ) -> Self {

        ParsingError(
            kind: .unexpectedElementTag(node: node, expectedTag: expectedTag),
            source: source,
            stackTrace: stackTrace
        )
    }

    /// O nó HTML tem filhos (extração de texto não funciona muito bem, nesse caso).
    static func nodeHasChildren(
        node: Node,
        source: ErrorSource = .capture(),
        stackTrace: StackTrace? = .capture()
    ) -> Self {

        ParsingError(kind: .nodeHasChildren(node: node), source: source, stackTrace: stackTrace)
    }

    /// Texto extraído do HTML não pôde ser parseado.
    static func unparseableText(
        node: Node,
        type: Any.Type,
        source: ErrorSource = .capture(),
        stackTrace: StackTrace? = .capture()
    ) -> Self {

        ParsingError(kind: .unparseableText(node: node, type: type), source: source, stackTrace: stackTrace)
    }

    /// Sequência deveria ter um único nó, mas tem mais de um.
    static func sequenceHasMoreThanOneElement(
        nodes: [Node],
        source: ErrorSource = .capture(),
        stackTrace: StackTrace? = .capture()
    ) -> Self {

        ParsingError(kind: .sequenceHasMoreThanOneElement(nodes: nodes), source: source, stackTrace: stackTrace)
    }

    // MARK: - DebuggableError

    let stackTrace: StackTrace?

    let source: ErrorSource?

    var logLevel: Logger.Level {
        .error
    }

    var identifier: String {
        switch self.kind {
            case .missingElement:
                return "missingElement"
            case .nodeHasChildren:
                return "nodeHasChildren"
            case .unexpectedElementTag:
                return "unexpectedElementTag"
            case .unparseableText:
                return "unparseableText"
            case .sequenceHasMoreThanOneElement:
                return "sequenceHasMoreThanOneElement"
        }
    }

    var reason: String {
        switch self.kind {
            case .missingElement:
                return "HTML Element is missing (nil)"
            case .nodeHasChildren(let node):
                return "An HTML Node has children, which was not expected: \(Self.asHTML(node))"
            case .unexpectedElementTag(let node, let tag):
                return "An HTML Element did not have the expected tag (\(tag)): \(Self.asHTML(node))"
            case .unparseableText(let node, let type):
                return "The text content of HTML element could not be parsed as \(type): \(Self.asHTML(node))"
            case .sequenceHasMoreThanOneElement(let nodes):
                let nodesString = nodes.map { Self.asHTML($0) }.joined(separator: ", ")
                return "Sequence expected to have a single element, has more than one: [\(nodesString)]"
        }
    }

    /// Representação textual do nó HTML.
    private static func asHTML(_ node: Node) -> String {
        (try? node.outerHtml()) ?? "[could not be represented]"
    }
}
