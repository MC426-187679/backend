import Foundation
import Logging

/// Algum dado que é recuperado por um dos
/// scipts de Web Scraping.
public protocol WebScrapable: Decodable {
    static var scriptName: String { get }
}

/// Executa a função, marcando o tempo demorado.
private func timed<T>(run: () throws -> T) rethrows -> (elapsed: Double, value: T) {
    let start = DispatchTime.now()
    let value = try run()
    let end = DispatchTime.now()

    let diff = end.uptimeNanoseconds - start.uptimeNanoseconds
    let elapsed = Double(diff) / 1E9
    return (elapsed, value)
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
            let (elapsed, ()) = try timed {
                try script.cleanExecution()
            }
            logger?.info("\(self.scriptName) done in \(elapsed) secs.")
        }

        let (elapsed, parsed) = try timed {
            try script.parseFilesWith { data in
                try JSONDecoder().decode([Self].self, from: data)
            }
        }
        logger?.info("Decoded \(self.scriptName) in \(elapsed) secs.")

        return parsed
    }
}


/// Um dos scripts em Python dentro da pasta `/Scraping`.
private class WebScrapingScript {
    /// Caminho para o script.
    fileprivate let script: URL
    /// Pasta com os artefatos gerados pelo script.
    fileprivate let buildFolder: URL

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
    convenience init(filename: String) {
        self.init(name: filename.strippedExtension())
    }

    /// Remove diretório de saída do script (`buildFolder`), se existir.
    func clearDir() {
        do {
            try FileManager.default.removeItem(at: buildFolder)
        } catch {
            // ignora erros durante remoção
        }
    }

    /// Cria diretório de saída do script (`buildFolder`).
    func createDir() throws {
        try FileManager.default.createDirectory(
            at: buildFolder,
            withIntermediateDirectories: true
        )
    }

    /// Executa o script e gera os resultados no diretório de saída (`buildFolder`).
    func executeScript() throws {
        let exec = URL(fileURLWithPath: "/usr/bin/env")
        let args = ["python3", script.path, buildFolder.path]

        let task = try Process.run(exec, arguments: args)
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            throw WebScrapingError(
                script: self,
                exitCode: task.terminationStatus
            )
        }
    }

    /// Limpa o diretório de saída (`buildFolder`) e executa o script.
    func cleanExecution() throws {
        clearDir()
        try createDir()
        try executeScript()
    }

    /// Retorna se o diretório de saída (`buildFolder`) já existe.
    var buildFolderExists: Bool {
        var isDirectory = ObjCBool(false)

        let exists = FileManager.default.fileExists(
            atPath: buildFolder.path,
            isDirectory: &isDirectory
        )
        return exists && isDirectory.boolValue
    }

    /// Retorna todos os arquivos no diretório de saída (`buildFolder`).
    func allFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: buildFolder,
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

        let parsed = try allFiles().concurrentMap { filename -> (String, T) in
            let contents = try Data(contentsOf: filename)
            let name = filename.deletingPathExtension().lastPathComponent

            return (name, try parse(contents))
        }
        return Dictionary(uniqueKeysWithValues: parsed)
    }
}

/// Erro de execução de um script de Web Scraping.
private struct WebScrapingError: Error, LocalizedError, RecoverableError {
    /// Script que estava sendo executado.
    let script: WebScrapingScript
    /// Código de retorno da execução.
    let exitCode: Int32

    /// Caminho do arquivo de script.
    var scriptPath: String {
        script.script.path
    }

    var errorDescription: String? {
        "Script '\(scriptPath)' exited with unexpected status code"
    }

    var failureReason: String? {
        "Script '\(scriptPath)' exited with code \(exitCode)"
        + " when running with WebScrapingScript"
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
    enum Options: String, CaseIterable {
        case simpleRerun = "Re-run script without any changes"
        case clearExec = "Clear directory and re-run script"
    }
}
