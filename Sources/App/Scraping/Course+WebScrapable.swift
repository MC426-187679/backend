import Foundation
import SwiftSoup

/// URL do índice de disciplinas.
private let indexURL = "https://www.dac.unicamp.br/sistemas/catalogos/grad/catalogo2021/index.html"

extension Course: WebScrapable {
    // MARK: - Scraping de disciplinas.

    static func scrape(with scraper: WebScraper) async throws -> [Course] {
        // carrega e parseia o índice
        let index = try await scraper.getHTML(from: indexURL)
        return try await scrapeIndex(page: index, with: scraper)
    }

    /// Parsing da página índice para encontrar os links das páginas de cursos e parsear cada uma.
    private static func scrapeIndex(page: Document, with scraper: WebScraper) async throws -> [Course] {
        // todos os links que seguem o padrão './cursos/00g/sugestao.html'
        let links = try page.getElementsByAttributeValueMatching("href", "^./cursos/[0-9]+g/sugestao\\.html$")

        // as páginas podem ser requisitadas e parseadas em qualquer ordem
        return try await links.asyncUnorderedMap { link in
            let document = try await scraper.getHTML(from: try link.absUrl("href"))
            return try parseCourse(from: try document.getElementById("principal"))
        }
    }

    // MARK: - Parsing do curso.

    /// Parser de um curso a partir do seu header (elemento com id 'principal').
    ///
    /// - throws: Se o elemento não pode ser entendido como um curso.
    private static func parseCourse(from header: Element?) throws -> Course {
        // o nome e o código ficam em um header 'h1' logo no começo do documento
        let headerTag = try ParsingUtils.unwrapSingleElement(header?.getElementsByTag("h1"))
        let (code, name) = try ParsingUtils.parseText(from: headerTag, expectedTag: "h1") { try parseHeader(in: $0) }

        // as modalidades nos filhos do próximo elemento
        let sections = try header?.nextElementSibling()?.children()
        let variants = try sections?.compactMap { try parseVariant(from: $0) } ?? []

        let curriculum: Curriculum
        switch variants.count {
            case 0:
                throw ParsingError.missingElement()
            case 1:
                curriculum = .tree(variants.first!.tree)
            default:
                curriculum = .variants(variants)
        }
        return Course(code: code, name: name, curriculum: curriculum)
    }

    /// Parser do texto do header (`<h1>`) de um curso.
    ///
    /// - parameter text: Texto no formato `'Curso $CÓDIGO - $Nome - Proposta para Cumprimento de Currículo'`.
    /// - returns: Uma tupla `($CÓDIGO, $Nome)` ou `nil` se o texto está em outro formato.
    private static func parseHeader(in text: String) throws -> (code: String, name: String)? {
        var parts = text.split(separator: "-", omittingEmptySubsequences: true)
        guard
            parts.count > 2,
            let code = try parseCode(in: parts.removeFirst().reducingWhitespace()),
            parts.removeLast().reducingWhitespace() == "Proposta para Cumprimento de Currículo"
        else {
            return nil
        }

        return (code, name: parts.joined(separator: "-").reducingWhitespace())
    }

    /// Regex para a extração do código a partir do header `Curso $CÓDIGO`.
    private static let courseCodeRegex = Result {
        try RegularExpression(pattern: "^Curso ([0-9]+)G$")
    }

    /// Parser do texto `Curso $CÓDIGO` do header do curso.
    ///
    /// - parameter text: Texto no formato `Curso 00G`.
    /// - returns: O código (`00` no exemplo) ou `nil` se o texto ou o código estão inválidos.
    /// - throws: Problemas com a ``courseCodeRegex``.
    private static func parseCode(in text: String) throws -> String? {
        try courseCodeRegex.get()
            .firstMatch(in: text)?
            .groups.first
            .map { String($0) }
    }

    // MARK: - Parsing da modalidade.

    /// Nome do curso de medicina, que tem parsing da árvore diferente (anual em vez de semestral).
    private static let medicineName = "Medicina"

    /// Parser de uma modalidade do curso a partir do trecho HTML específico.
    ///
    /// - parameter section: Trecho de HTML.
    /// - returns: Uma modalidade do curso ou `nil` se for a seção de `'Observação`.
    /// - throws: Se a seção não pode ser tratada como modalidade.
    /// - attention: O `nil` aqui tem um significado um pouco diferente dos demais parsers.
    private static func parseVariant(from section: Element) throws -> Variant? {
        // o nome da modalidade fica no 'h2', primeiro elemento da seção
        let header = try ParsingUtils.unwrapSingleElement(try section.getElementsByTag("h2"))
        let (name, code) = try ParsingUtils.parseText(from: header, expectedTag: "h2") { text in
            parseVariantHeader(in: text)
        }
        // observação é a última dessas seções no documento, e deve ser considerada válida
        guard name != "Observação" else {
            return nil
        }

        // os elementos seguintes são uma lista de paragrafos com um header cada, as disciplinas ficam nos <p>
        let tree = try header.parent().map { treeTable -> Tree in
            if name == medicineName {
                return try parseMedicineTree(from: treeTable)
            } else {
                return try parseTree(from: treeTable)
            }
        }
        guard
            let code = code,
            let tree = tree,
            tree.reduce(0, { $0 + $1.credits }) > 0
        else {
            throw ParsingError.unparseableText(node: section, type: Variant.self)
        }

        return Variant(name: name, code: code, tree: tree)
    }

    /// Parsing da árvore de uma modalidade.
    ///
    /// parameter treeTable: Tabela no HTML que representa a árvore da modalidade.
    /// returns: Árvore com os semestres parseados.
    private static func parseTree(from treeTable: Element) throws -> Tree {
        try treeTable.getElementsByTag("p").enumerated().map { (row, content) in
            try Semester.parseSemester(from: content, at: row).semester
        }
    }

    /// Parsing da árvore do curso `"Medicina"`.
    ///
    /// parameter treeTable: Tabela no HTML que representa a árvore do curso.
    /// returns: Árvore com os semestres parseados.
    /// attention: Semestres vazios são considerados continuações do semestre anterior.
    private static func parseMedicineTree(from treeTable: Element) throws -> Tree {
        let emptySemester = Semester(disciplines: [], electives: 0)
        var semesters: [Semester] = .init(repeating: emptySemester, count: 12)

        try treeTable.getElementsByTag("p").forEach { content in
            let (index, semester) = try Semester.parseSemester(from: content)
            semesters[index] = semester
        }
        return semesters
    }

    /// Parser do texto do header (`<h2>`) de uma modalidade.
    ///
    /// - parameter text: Texto no formato `'$CÓDIGO - $Nome'` ou somente `'$Nome'`.
    /// - returns: Uma tupla `($Nome, $CÓDIGO?)` ou `nil` se o texto está vazio.
    private static func parseVariantHeader(in text: String) -> (name: String, code: String?)? {
        let parts = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)

        guard let first = parts.get(at: 0)?.reducingWhitespace() else {
            return nil
        }

        if let name = parts.get(at: 1)?.reducingWhitespace() {
            return (name, code: first)
        } else {
            return (name: first, nil)
        }
    }
}

extension Course.Semester {

    // MARK: - Parsing de um semestre de um curso.

    /// Extrai semestre a partir de um parágrafo e das sua posição na seção da modalidade.
    ///
    /// - parameter row: Elemento `<p>` onde cada disciplina está representada por um `<span>` com um texto
    ///     no formato $CODIGO ($NUMERO)`.
    /// - parameter index: Índice do parágrafo do semestre dentro da seção da modalidade, ignorado se `nil`.
    /// - returns: O índice e o semestre, com as disciplinas obrigatórias e a quantidade de créditos eletivos.
    fileprivate static func parseSemester(
        from paragraph: Element,
        at index: Int? = nil
    ) throws -> (index: Int, semester: Self) {
        // garante que a numeração do semestre está correta
        let number = try ParsingUtils.parseText(
            from: try paragraph.previousElementSibling(),
            expectedTag: "h3",
            with: { text in
                try parseSemesterNumber(in: text.reducingWhitespace(), expecting: index.map { $0 + 1 })
            }
        )
        // só então parseia a linha do <p>
        let electives = try parseElectiveCredits(from: paragraph)
        let disciplines = try parseSemesterDisciplines(from: paragraph)
        // um semestre não pode ser vazio de tudo, eu acho
        guard !disciplines.isEmpty || electives > 0 else {
            throw ParsingError.unparseableText(node: paragraph, type: Self.self)
        }

        return (number - 1, Self(disciplines: ArraySet(uniqueValues: disciplines), electives: electives))
    }

    /// Regex para a extração do semestre a partir do texto `00º Semestre - 00 créditos`.
    private static let semesterNumberRegex = Result {
        try RegularExpression(pattern: "^([0-9]+)º Semestre - [0-9]+ créditos$")
    }

    /// Parser do texto com numeração do semestre.
    ///
    /// - parameter text: Texto no formato `00º Semestre - 11 créditos`.
    /// - parameter expected: Valor esperado para o resultado.
    /// - returns: O número do semestre ou `nil` se o texto não segue o formato ou se é diferente de `expected`.
    /// - throws: Problemas com a ``semesterNumberRegex``.
    private static func parseSemesterNumber(in text: String, expecting expected: Int? = nil) throws -> Int? {
        guard
            let matches = try semesterNumberRegex.get().firstMatch(in: text),
            let semesterText = matches.groups.first,
            let semesterNumber = Int(semesterText),
            expected == nil || semesterNumber == expected
        else {
            return nil
        }
        return semesterNumber
    }

    /// Dá match em `$CODIGO ($NUMERO)`, onde `$CODIGO` é composto por 5 caracteres maiusculos ou dígitos
    /// e `$NUMERO` é um número decimal não-negativo.
    private static let disciplineCodeRegex = Result {
        try RegularExpression(pattern: "^([A-Z 0-9]{5}) [(]([0-9]+)[)]")
    }

    /// Extrai códigos e quantidade de créditos de cada disciplina no semestre.
    ///
    /// - parameter row: Elemento `<p>` onde cada disciplina está representada por um `<span>` com um texto
    ///     no formato $CODIGO ($NUMERO)`.
    /// - returns: Cada código de cada disciplina no semestre com sua quantidade de créditos.
    private static func parseSemesterDisciplines(from row: Element) throws -> [DisciplinePreview] {
        try row.getElementsByTag("a").map { element in
            try ParsingUtils.parseText(from: element, expectedTag: "a") { text in
                guard
                    let matches = try disciplineCodeRegex.get().firstMatch(in: text.reducingWhitespace())?.groups,
                    let uncheckedCode = matches.get(at: 0),
                    let code = try Discipline.parseCode(in: String(uncheckedCode)),
                    let creditsText = matches.get(at: 1),
                    let credits = UInt(creditsText)
                else {
                    return nil
                }
                return DisciplinePreview(code: code, credits: credits)
            }
        }
    }

    /// Regex para a extração do semestre a partir do texto `00º Semestre - 00 créditos`.
    private static let electivesRegex = Result {
        try RegularExpression(pattern: "^([0-9]+) créditos eletivo(s)?$")
    }

    /// Scraper de créditos eletivos.
    ///
    /// - parameter row: Elemento `<p>` com as disciplinas do semestre.
    /// - return: Quantidade de créditos eletivos.
    private static func parseElectiveCredits(from row: Element) throws -> UInt {
        // busca pelo texto eletivo deve resultar em 0 ou 1 elemento
        let elements = try row.getElementsContainingOwnText("eletivo")
        guard !elements.isEmpty() else {
            return 0
        }

        let span = try ParsingUtils.unwrapSingleElement(elements)
        // se um elemento, deve ser um `<span>00 créditos eletivos</span>`
        return try ParsingUtils.parseText(from: span, expectedTag: "span") { text in
            try electivesRegex.get()
                .firstMatch(in: text.reducingWhitespace())?
                .groups.first
                .flatMap { UInt($0) }
        }
    }
}
