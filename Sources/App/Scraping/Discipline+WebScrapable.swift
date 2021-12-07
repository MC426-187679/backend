import Foundation
import SwiftSoup

/// URL do índice de disciplinas.
private let indexURL = "https://www.dac.unicamp.br/sistemas/catalogos/grad/catalogo2021/disciplinas/index.html"

extension Discipline: WebScrapable {
    // MARK: - Scraping de disciplinas.

    static func scrape(with scraper: WebScraper) async throws -> [Discipline] {
        // carrega e parseia o índice
        let index = try await scraper.getHTML(from: indexURL)
        let disciplines = try await scrapeIndex(page: index, with: scraper)
        return self.updateDisciplines(disciplines)
    }

    /// Parsing da página índice para encontrar os links das páginas de disciplinas e parsear cada uma.
    private static func scrapeIndex(page: Document, with scraper: WebScraper) async throws -> [Discipline] {
        // todos os links que seguem o padrão '../disciplinas/XX.html'
        let links = try page.getElementsByAttributeValueMatching("href", "^../disciplinas/..\\.html$")

        // as páginas podem ser requisitadas e parseadas em qualquer ordem
        let results = try await links.asyncUnorderedMap { link -> [Discipline] in
            let document = try await scraper.getHTML(from: try link.absUrl("href"))
            return try scrapeDisciplines(page: document)
        }
        return results.flatMap { $0 }
    }

    /// Parsing de uma página com várias disciplinas, em geral seguindo o mesmo padrão de sigla.
    private static func scrapeDisciplines(page: Document) throws -> [Discipline] {
        // acha os headers (h2) de cada disciplina, com id no formato 'disc-XX000'
        let headers = try page.getElementsByAttributeValueMatching("id", "^disc-..[0-9][0-9][0-9]$")

        return try headers.compactMap { header in
            try parseDiscipline(from: header)
        }
    }

    /// Atualiza os campos `special` e `reqBy` nos dados de disciplinas.
    private static func updateDisciplines(_ disciplines: [Discipline]) -> [Discipline] {
        let (present, requiredBy) = self.extractPresentAndReqBy(from: disciplines)

        return disciplines.map { discipline in
            let reqs = discipline.reqs.map { requirementGroup in
                ArraySet(uniqueValues: requirementGroup.map { requirement in
                    requirement.update(special: !present.contains(requirement.code))
                })
            }
            let reqBy = ArraySet(requiredBy[discipline.code] ?? [])
            return discipline.update(reqs: ArraySet(uniqueValues: reqs), reqBy: reqBy)
        }
    }

    /// Extração de dados necessários para atualizar os dados das dsiciplinas.
    private static func extractPresentAndReqBy(
        from disciplines: [Discipline]
    ) -> (present: Set<String>, reqBy: [String: Set<String>]) {

        var requiredBy: [String: Set<String>] = [:]
        var present: Set<String> = []

        for discipline in disciplines {
            present.update(with: discipline.code)

            discipline.reqs.flatMap({ $0 }).forEach { requirement in
                var codes = requiredBy[requirement.code] ?? []
                codes.update(with: discipline.code)
                requiredBy[requirement.code] = codes
            }
        }
        return (present, requiredBy)
    }

    // MARK: - Parsing da disciplina.

    /// Parser de uma disciplina a partir do seu header (elemento com id 'disc-$CÓDIGO').
    ///
    /// - important: Assume todos os pré-requisitos como especiais e não faz tratamento do campo `reqBy`.
    /// - throws: Se o elemento não pode ser entendido como uma disciplina.
    private static func parseDiscipline(from header: Element) throws -> Discipline {
        let (code, name) = try ParsingUtils.parseText(from: header, expectedTag: "h2") { try parseHeader(in: $0) }

        // as seções da disciplina são feitas por um <h3> (titulo da seção) seguido de
        // um <p> ou <div> (corpo da seção), que deve vir logo após o elemento
        let sections = try ParsingUtils.parseHTMLSections(header.parent(), headerTag: "h3") { sectionHeader in
            try sectionHeader.nextElementSibling()
        }
        // a ementa é o texto de uma seção com título "Ementa"
        let syllabus = try ParsingUtils.getText(from: sections["Ementa"], ignoreChildren: true)
        // a carga horária é um pouco diferente, as seções tem como título um <strong>, mas o conteúdo fica
        // perdido dentro do elemento pai, e precisa ser acessado como um nó com apenas texto
        let workload = try ParsingUtils.parseHTMLSections(sections["Carga Horária"], headerTag: "strong") { header in
            header.nextSibling()
        }
        // um nó (que não é elemento) tem tag vazia
        let credits = try ParsingUtils.parseText(from: workload["Total de Créditos:"], expectedTag: "") { UInt($0) }
        // os pré-requisitos são extraído de um texto simples (não da formatação do HTML)
        let reqs = try ParsingUtils.parseText(from: sections["Pré-requisitos"], expectedTag: "p") {
            try parseAllRequirements(in: $0)
        }

        return Discipline(code: code, name: name, credits: credits, reqs: reqs, reqBy: [], syllabus: syllabus)
    }

    /// Parser do texto do header (`<h2 id="disc-XX000">`) de uma discplina.
    ///
    /// - Parameter text: Texto no formato `'$CÓDIGO - $Nome'`.
    /// - Returns: Uma tupla `($CÓDIGO, $Nome)` ou `nil` se o texto está em outro formato.
    private static func parseHeader(in text: String) throws -> (code: String, name: String)? {
        let parts = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        guard
            let uncheckedCode = parts.get(at: 0)?.reducingWhitespace(),
            // use parseRequirement para garantir que o código é válido
            let code = try parseCode(in: uncheckedCode),
            let name = parts.get(at: 1)?.reducingWhitespace()
        else {
            return nil
        }
        return (code, name)
    }

    /// Parser da seção de pré-requisitos, que aceita
    ///
    /// - Parameter text: O texto padrão quando não existe requisito ou o texto de requisitos no formato
    ///     `$GRUPO (ou $GRUPO)...` em que `$GRUPO` tem o formato `$CODIGO(+$CODIGO)...` e o código é aceito
    ///      por ``parseRequirement``.
    /// - Returns: Um conjunto de grupos de requisitos ou `nil` se o texto está em outro formato.
    private static func parseAllRequirements(in text: String) throws -> ArraySet<ArraySet<Requirement>>? {
        guard text.reducingWhitespace() != "Não há pré-requisitos para essa disciplina" else {
            return []
        }

        return try parseTextualGroup(in: text, separatedBy: "ou") { group in
            try parseTextualGroup(in: group, separatedBy: "+") { requirement in
                try parseRequirement(in: requirement)
            }
        }
    }

    /// Parser de um grupo textual.
    ///
    /// - parameter text: Texto no formato `$ITEM ($sep $ITEM)...`.
    /// - parameter separator: O separador de elementos do grupo (`$sep`).
    /// - parameter parser: Função que faz o parsing de cada item do grupo.
    /// - returns: Conjunto dos itens do grupo.
    private static func parseTextualGroup<Item: Hashable>(
        in text: String,
        separatedBy separator: String,
        parser: (String) throws -> Item?
    ) rethrows -> ArraySet<Item>? {
        try text.components(separatedBy: separator)
            .filter { !$0.isEmpty }
            .tryMap { try parser($0.reducingWhitespace()) }
            .map { results in ArraySet(uniqueValues: results) }
    }

    /// Regex que dá match com código de disciplinas e opcionalmente o marcador `*` de pré-requisito parcial.
    private static let disciplineCodeRegex = Result {
        try RegularExpression(pattern: "^(\\*?)([A-Z][A-Z ][0-9][0-9][0-9])$")
    }

    /// Parser de um pré-requisito de disciplina.
    ///
    /// - parameter text: Texto no formato `XX000` ou `*XX000`.
    /// - returns: Pré-requisito de uma disciplina.
    /// - throws: Problemas com a ``disciplineCodeRegex``.
    /// - important: Assume que o código é especial, para ser corrigido depois.
    private static func parseRequirement(in text: String) throws -> Requirement? {
        guard
            let matches = try disciplineCodeRegex.get().firstMatch(in: text)?.groups,
            let partialMarker = matches.get(at: 0),
            let code = matches.get(at: 1)
        else {
            return nil
        }
        return Requirement(code: String(code), partial: !partialMarker.isEmpty, special: true)
    }

    /// Parser de um código de disciplina.
    ///
    /// - parameter text: Texto no formato `XX000`.
    /// - returns: O mesmo código, caso seja válido.
    static func parseCode(in text: String) throws -> String? {
        try parseRequirement(in: text).flatMap { requirement in
            if requirement.partial {
                return nil
            } else {
                return requirement.code
            }
        }
    }
}
