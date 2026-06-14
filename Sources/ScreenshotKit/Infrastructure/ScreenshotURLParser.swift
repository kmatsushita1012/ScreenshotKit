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
    public init() {}

    public func parse(_ url: URL, expectedScheme: String) -> ScreenshotRoute? {
        guard url.scheme == expectedScheme else { return nil }
        guard url.host == "screenshot" else { return nil }

        let components = url.pathComponents.filter { $0 != "/" }
        guard let last = components.last else { return nil }

        switch last {
        case "start":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let deviceName = components?
                .queryItems?
                .first(where: { $0.name == "deviceName" })?
                .value?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return ScreenshotRoute(command: .start(deviceName: sanitizedDeviceName(deviceName)))
        default:
            return nil
        }
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
