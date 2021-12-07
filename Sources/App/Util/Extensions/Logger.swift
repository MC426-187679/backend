import Vapor

extension Logger {
    /// Baseado no `Logger.report` do Vapor.
    internal func report(
        level: Logger.Level? = nil,
        _ error: Error,
        Service type: Any.Type? = nil,
        additional message: @autoclosure () -> String? = nil,
        metadata: @autoclosure () -> [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        let debuggable = error as? DebuggableError
        let source = debuggable?.source
        let defaultLevel = debuggable?.logLevel

        self.log(
            level: level ?? defaultLevel ?? .warning,
            self.message(for: error, additional: message()),
            metadata: self.metadata(for: type, error, with: metadata()),
            file: source?.file ?? file,
            function: source?.function ?? function,
            line: source?.line ?? line
        )
    }

    /// Builds `Logger.Metadata` from string pairs.
    private  func metadata(
        for service: Any.Type?,
        _ error: Error,
        with additional: [String: String]
    ) -> Logger.Metadata {
        var metadata = additional.mapValues { Logger.MetadataValue.string($0) }

        if let type = service {
            metadata["dervice"] = "\(type)"
        }
        metadata["error"] = .stringConvertible(error as CustomStringConvertible)
        return metadata
    }

    /// Builds `Logger.Message` from report input.
    private func message(for error: Error, additional message: String?) -> Logger.Message {
        let reason: String
        switch error {
            case let debuggable as DebuggableError:
                if self.logLevel <= .trace {
                    reason = debuggable.debuggableHelp(format: .long)
                } else {
                    reason = debuggable.debuggableHelp(format: .short)
                }
            case let abort as AbortError:
                reason = abort.reason
            case let localized as LocalizedError:
                reason = localized.localizedDescription
            case let convertible as CustomStringConvertible:
                reason = convertible.description
            default:
                reason = "\(error)"
        }

        if let message = message {
            return Logger.Message(stringLiteral: "\(message): \(reason)")
        } else {
            return Logger.Message(stringLiteral: reason)
        }
    }
}
