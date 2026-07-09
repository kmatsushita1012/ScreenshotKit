import Foundation

enum Utilities {
    static func sanitizePathComponent(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let sanitized = String(
            value.unicodeScalars.map { invalidCharacters.contains($0) ? Character("-") : Character($0) }
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized.isEmpty ? "unknown-device" : sanitized
    }

    static func outputRootURL(from value: String, relativeTo directory: URL) -> URL {
        let expanded = NSString(string: value).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded, isDirectory: true)
        }
        return directory.appendingPathComponent(expanded, isDirectory: true)
    }

    static func resolvePath(_ value: String, relativeTo directory: URL) -> String {
        let expanded = NSString(string: value).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL.path
        }
        return directory.appendingPathComponent(expanded).standardizedFileURL.path
    }

    static func parseAppleLocaleValues(localeIdentifier: String) -> (languages: String, locale: String) {
        let normalized = localeIdentifier.replacingOccurrences(of: "_", with: "-")
        let language = normalized.split(separator: "-", maxSplits: 1).first.map(String.init) ?? normalized

        var values = [normalized]
        if language != normalized {
            values.append(language)
        }

        let languages = "(\(values.map { "\"\($0)\"" }.joined(separator: ",")))"
        return (languages, normalized.replacingOccurrences(of: "-", with: "_"))
    }

    static func sleep(seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
