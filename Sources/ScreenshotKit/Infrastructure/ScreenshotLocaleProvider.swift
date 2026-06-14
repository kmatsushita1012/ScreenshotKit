import Foundation

public protocol ScreenshotLocaleProviderProtocol: Sendable {
    func localeIdentifiers() -> [String]
}

public struct ScreenshotLocaleProvider: ScreenshotLocaleProviderProtocol, Sendable {
    private let bundle: Bundle

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    public func localeIdentifiers() -> [String] {
        let localizations = bundle.localizations
            .filter { $0.caseInsensitiveCompare("Base") != .orderedSame }
            .map(normalizedLocaleIdentifier)

        let uniqueLocalizations = Array(NSOrderedSet(array: localizations)) as? [String] ?? localizations

        if !uniqueLocalizations.isEmpty {
            return uniqueLocalizations
        }

        if let developmentLocalization = bundle.developmentLocalization, !developmentLocalization.isEmpty {
            return [normalizedLocaleIdentifier(developmentLocalization)]
        }

        return [normalizedLocaleIdentifier(Locale.current.identifier)]
    }

    private func normalizedLocaleIdentifier(_ identifier: String) -> String {
        if identifier.contains("-") || identifier.contains("_") {
            return identifier.replacingOccurrences(of: "_", with: "-")
        }

        let defaults: [String: String] = [
            "ja": "ja-JP",
            "en": "en-US",
            "ko": "ko-KR",
            "fr": "fr-FR",
            "de": "de-DE",
            "it": "it-IT",
            "es": "es-ES",
            "pt": "pt-BR",
            "zh-Hans": "zh-CN",
            "zh-Hant": "zh-TW"
        ]

        return defaults[identifier] ?? identifier
    }
}
