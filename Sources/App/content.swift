import Foundation
import Vapor
import Services


/// Dados que podem ser retornados após a busca.
///
/// A forma reduzida é usada para enviar menos informação
/// para o cliente, removendo alguns campos que só são
/// úteis quando requisitados epsecificamente.
protocol Matchable: Searchable {
    /// Nome que identifica o tipo para o cliente.
    static var contentName: String { get }

    /// Forma reduzida do dado, usada como preview
    /// durante a busca.
    associatedtype ReducedForm: Encodable

    /// Reduz o dado.
    func reduced() -> ReducedForm
}

extension Matchable {
    @inlinable
    static var contentName: String {
        "\(Self.self)".lowercased()
    }
}

/// Controlador de dados buscáveis.
protocol ContentController {
    /// Tipo do dado que ele controla.
    associatedtype Content: Matchable

    /// Busca textual no conjunto de dados.
    ///
    /// - Parameter text: Texto a ser buscado.
    /// - Parameter maxScore: Maior score que ainda
    ///   pode ser considerado um match.
    ///
    /// - Returns: Vetor com os dados que deram match
    ///   e o score de cada item para a query. Dados
    ///   com um score menor que `maxScore` não são
    ///   retornados.
    func search(for text: String, upTo maxScore: Double) -> [(item: Content, score: Double)]
}

extension ContentController {
    /// Busca textual no conjunto de dados.
    ///
    /// Os resultados da busca são retornados de
    /// já forma ordenada. Apenas os `matches`
    /// melhores scores são retornados.
    ///
    /// - Parameter text: Texto a ser buscado.
    /// - Parameter matches: Quantidade máxima de
    ///   dados que deve ser retornada. Os dados com
    ///   os menores scores são ignorados.
    /// - Parameter maxScore: Maior score que ainda
    ///   pode ser considerado um match.
    ///
    /// - Returns: Vetor ordenado com os matches do
    ///   conjunto de dados. O vetor é limitado aos
    ///   `matches` melhores scores e todos os dados
    ///   tem um score menor que `maxScore`.
    func search(for text: String, limitedTo matches: Int, upTo maxScore: Double) -> [Match] {
        var results = self.search(for: text, upTo: maxScore)
        results.sort(on: { $0.score })

        let contentName = Content.contentName
        return results.prefix(matches).map {
            Match($0.item.reduced(), $0.score, contentName)
        }
    }
}

extension Logger {
    /// ContentController logger.
    static var controllerLogger = Logger(label: "ContentController")
}

/// Representa um match no conjunto de dados.
///
/// Útil para trabalhar com matches de tipos
/// diferentes, mas que ainda podem ser
/// enviados como JSON.
struct Match {
    /// O item a ser enviado.
    let item: Encodable
    /// O score do item, usado para comparação.
    let score: Double
    /// Descrição do conteúdo, para ser usado no front.
    let content: String

    fileprivate init(_ item: Encodable, _ score: Double, _ content: String) {
        self.item = item
        self.score = score
        self.content = content
    }

    /// Se o score da match deve ser enviada também.
    private static var sendScore = false
    /// Ajusta para enviar scores no resultado.
    static func encodeScoresForSending() {
        self.sendScore = true
    }
}

extension Match: Content {
    /// Não faz sentido receber um `Match` do cliente,
    /// mas é necessário para funcionamento com o Vapor.
    init(from decoder: Decoder) throws {
        throw DecodingError.typeMismatch(Never.self, .init(
            codingPath: [],
            debugDescription: "Can't decode to a Match"
        ))
    }

    /// Um `Match` é formatado como seu item interno, além
    /// da descrição e possivelmente do score.
    func encode(to encoder: Encoder) throws {
        // encoda o item primeiro
        try self.item.encode(to: encoder)
        // depois a descrição e o score
        var container = encoder.container(keyedBy: MatchKeys.self)
        try container.encode(self.content, forKey: .content)
        if Self.sendScore {
            try container.encode(self.score, forKey: .score)
        }
    }

    /// Chaves adicionais da match.
    private enum MatchKeys: CodingKey {
        case score
        case content
    }
}
