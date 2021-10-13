import Foundation
import Logging

/// Algum dado que é recuperado por um dos
/// scipts de Web Scraping.
public protocol WebScrapable: Decodable {
    static var scriptName: String { get }
}

public extension WebScrapable {
    /// Executa o script de Scraping e parseia o resultado.
    ///
    /// Usa um logger para avisar o estado da execução.
    ///
    /// - Returns: Dicionário com o nome de cada arquivo construído
    ///   e seus resultados parseados.
    static func scrape(logger: Logger? = nil) throws -> [String: [Self]] {
        logger?.info("Scraping with \(self.scriptName)...")
        let script = WebScrapingScript(filename: self.scriptName)

        // executa o script apenas se necessário
        if !script.buildFolderExists {
            logger?.info("Rebuilding artifacts for \(self.scriptName)...")
            let elapsed = try withTiming {
                try script.cleanExecution()
            }
            let totalFiles = try script.allFiles().count
            logger?.info("\(self.scriptName) done with \(totalFiles) files in \(elapsed) secs.")
        }

        let (elapsed, parsed) = try withTiming {
            try script.parseFilesWith { data in
                try JSONDecoder().decode([Self].self, from: data)
            }
        }
        let totalSize = parsed.values.reduce(0) { $0 + $1.count }
        logger?.info("Decoded \(self.scriptName) with \(totalSize) items in \(elapsed) secs.")

        return parsed
    }
}


/// Um dos scripts em Python dentro da pasta `/Scraping`.
private struct WebScrapingScript {
    /// Caminho para o script.
    let script: URL
    /// Pasta com os artefatos gerados pelo script.
    private let buildFolder: URL

    /// Prepara os caminhos usados pelo script.
    ///
    /// - Parameter name: Nome do script (sem a extensão '.py').
    init(name: String) {
        self.buildFolder = URL(
            fileURLWithPath: ".build/scraping/\(name)",
            isDirectory: true
        )
        self.script = URL(
            fileURLWithPath: "Scraping/\(name).py",
            isDirectory: false
        )
    }

    /// Prepara os caminhos usados pelo script.
    ///
    /// - Parameter filename: Nome do arquivo com o script,
    ///   possívelmente com uma extensão.
    init(filename: String) {
        self.init(name: filename.strippedExtension())
    }

    /// Remove diretório de saída do script (`buildFolder`), se existir.
    func clearDir() {
        do {
            try FileManager.default.removeItem(at: self.buildFolder)
        } catch {
            // ignora erros durante remoção
        }
    }

    /// Cria diretório de saída do script (`buildFolder`).
    func createDir() throws {
        try FileManager.default.createDirectory(
            at: self.buildFolder,
            withIntermediateDirectories: true
        )
    }

    /// Executa o script e gera os resultados no diretório de saída (`buildFolder`).
    func executeScript() throws {
        let exec = URL(fileURLWithPath: "/usr/bin/env")
        let args = ["python3", self.script.path, self.buildFolder.path]

        let task = try Process.run(exec, arguments: args)
        // checa se houve algum erro
        if let error = WebScrapingError(for: self, on: task) {
            throw error
        }
    }

    /// Limpa o diretório de saída (`buildFolder`) e executa o script.
    func cleanExecution() throws {
        self.clearDir()
        try self.createDir()
        try self.executeScript()
    }

    /// Retorna se o diretório de saída (`buildFolder`) já existe.
    var buildFolderExists: Bool {
        var isDirectory = ObjCBool(false)

        let exists = FileManager.default.fileExists(
            atPath: self.buildFolder.path,
            isDirectory: &isDirectory
        )
        return exists && isDirectory.boolValue
    }

    /// Retorna todos os arquivos no diretório de saída (`buildFolder`).
    func allFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: self.buildFolder,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        .filter { url in
            url.isFileURL && !url.hasDirectoryPath
        }
    }

    /// Parseia todos os arquivos no diretório de saída (`buildFolder`)
    /// com o `parser` dado.
    ///
    /// - Returns: Dicionário que associa o nome do arquivo
    ///   com seu valor parseado.
    func parseFilesWith<T>(parser parse: (Data) throws -> T) throws -> [String: T] {

        let parsed = try self.allFiles().concurrentMap { filename -> (String, T) in
            let contents = try Data(contentsOf: filename)
            let name = filename.deletingPathExtension().lastPathComponent

            return (name, try parse(contents))
        }
        return .init(uniqueKeysWithValues: parsed)
    }
}

/// Erro de execução de um script de Web Scraping.
private struct WebScrapingError: Error, LocalizedError, RecoverableError {
    /// Script que estava sendo executado.
    private let script: WebScrapingScript
    /// Tarefa que encerrou com falhas.
    private let task: Process

    /// Gera um erro para o `script` caso `task` falhe.
    init?(for script: WebScrapingScript, on task: Process) {
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            return nil
        }
        // processo falhou
        self.script = script
        self.task = task
    }

    /// Código de falha retornado na execução.
    private var exitCode: Int32 {
        self.task.terminationStatus
    }

    /// Descrição do método de encerramento do script.
    private var terminationReason: String {
        switch self.task.terminationReason {
            case .exit:
                return "exited normally"
            case .uncaughtSignal:
                return "termined by an uncaught signal"
        }
    }

    /// Caminho do arquivo de script.
    private var scriptPath: String {
        self.script.script.path
    }

    var errorDescription: String? {
        "Script '\(self.scriptPath)' ended with unexpected status code"
    }

    var failureReason: String? {
        "Script '\(self.scriptPath)' \(self.terminationReason) with "
        + "code \(self.exitCode) when running in WebScrapingScript"
    }

    var recoverySuggestion: String? {
        "Re-run script"
    }

    var recoveryOptions: [String] {
        Options.allCases.map { $0.rawValue }
    }

    func attemptRecovery(optionIndex index: Int) -> Bool {
        guard let option = Options.allCases.get(at: index) else {
            return false
        }

        do {
            switch option {
                case .simpleRerun:
                    try script.executeScript()
                case .clearExec:
                    try script.cleanExecution()
            }
            return true
        } catch {
            return false
        }
    }

    /// Opções de recuperação  para a execução.
    private enum Options: String, CaseIterable {
        case simpleRerun = "Re-run script without any changes"
        case clearExec = "Clear directory and re-run script"
    }
}
