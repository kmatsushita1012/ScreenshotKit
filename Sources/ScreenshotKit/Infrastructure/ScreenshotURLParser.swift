//
//  ScreenshotURLParser.swift
//  ScreenshotKit
//
//  Infra: URL -> Route parser
//

import Foundation

public protocol ScreenshotURLParserProtocol: Sendable {
    func parse(_ url: URL, expectedScheme: String) -> ScreenshotRoute?
}

public struct ScreenshotURLParser: ScreenshotURLParserProtocol, Sendable {
    private let supportedRouteComponents = Set(["screenshot", "screenshots"])

    public init() {}

    public func parse(_ url: URL, expectedScheme: String) -> ScreenshotRoute? {
        guard matchesScheme(url.scheme, expectedScheme: expectedScheme) else { return nil }
        let commandName = commandName(from: url)
        guard let commandName else { return nil }

        switch commandName {
        case "start":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let deviceName = components?
                .queryItems?
                .first(where: { $0.name == "deviceName" })?
                .value?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return ScreenshotRoute(command: .manifest(deviceName: sanitizedDeviceName(deviceName)))
        default:
            return nil
        }
    }

    private func commandName(from url: URL) -> String? {
        if let host = url.host?.lowercased(), supportedRouteComponents.contains(host) {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            return pathComponents.last
        }

        let normalizedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathComponents = normalizedPath
            .split(separator: "/")
            .map(String.init)

        guard pathComponents.count >= 2 else { return nil }
        guard supportedRouteComponents.contains(pathComponents[pathComponents.count - 2].lowercased()) else {
            return nil
        }
        return pathComponents.last
    }

    private func matchesScheme(_ actualScheme: String?, expectedScheme: String) -> Bool {
        actualScheme?.caseInsensitiveCompare(expectedScheme) == .orderedSame
    }

    private func sanitizedDeviceName(_ deviceName: String?) -> String {
        let fallback = "unknown-device"
        guard let deviceName, !deviceName.isEmpty else {
            return fallback
        }

        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let scalars = deviceName.unicodeScalars.map { invalidCharacters.contains($0) ? "-" : Character($0) }
        let candidate = String(scalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return candidate.isEmpty ? fallback : candidate
    }
}
