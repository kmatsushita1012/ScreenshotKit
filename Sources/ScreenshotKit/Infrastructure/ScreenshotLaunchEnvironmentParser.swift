import Foundation

public protocol ScreenshotLaunchEnvironmentParserProtocol: Sendable {
    func parse(processInfo: ProcessInfo) -> ScreenshotRoute?
}

public struct ScreenshotLaunchEnvironmentParser: ScreenshotLaunchEnvironmentParserProtocol, Sendable {
    public static let modeEnvironmentKey = "SCREENSHOTKIT_MODE"
    public static let deviceNameEnvironmentKey = "SCREENSHOTKIT_DEVICE_NAME"
    public static let sceneIDEnvironmentKey = "SCREENSHOTKIT_SCENE_ID"
    public static let localeEnvironmentKey = "SCREENSHOTKIT_LOCALE"
    public static let sessionDirectoryPathEnvironmentKey = "SCREENSHOTKIT_SESSION_PATH"
    public static let manifestModeValue = "manifest"
    public static let captureModeValue = "capture"
    public static let modeArgument = "--screenshotkit-mode"
    public static let deviceNameArgument = "--screenshotkit-device-name"
    public static let sceneIDArgument = "--screenshotkit-scene-id"
    public static let localeArgument = "--screenshotkit-locale"
    public static let sessionDirectoryPathArgument = "--screenshotkit-session-path"

    public init() {}

    public func parse(processInfo: ProcessInfo) -> ScreenshotRoute? {
        guard let mode = launchMode(processInfo: processInfo) else { return nil }

        let deviceName = sanitizedDeviceName(
            environmentDeviceName(processInfo: processInfo)
                ?? argumentValue(arguments: processInfo.arguments, name: Self.deviceNameArgument)
        )

        switch mode {
        case Self.manifestModeValue:
            return ScreenshotRoute(command: .manifest(deviceName: deviceName))
        case Self.captureModeValue:
            guard
                let sceneID = nonEmptyValue(
                    processInfo.environment[Self.sceneIDEnvironmentKey]
                        ?? argumentValue(arguments: processInfo.arguments, name: Self.sceneIDArgument)
                ),
                let localeIdentifier = nonEmptyValue(
                    processInfo.environment[Self.localeEnvironmentKey]
                        ?? argumentValue(arguments: processInfo.arguments, name: Self.localeArgument)
                ),
                let sessionDirectoryPath = nonEmptyValue(
                    processInfo.environment[Self.sessionDirectoryPathEnvironmentKey]
                        ?? argumentValue(arguments: processInfo.arguments, name: Self.sessionDirectoryPathArgument)
                )
            else {
                return nil
            }

            return ScreenshotRoute(
                command: .capture(
                    deviceName: deviceName,
                    sceneID: sceneID,
                    localeIdentifier: localeIdentifier,
                    sessionDirectoryPath: sessionDirectoryPath
                )
            )
        default:
            return nil
        }
    }

    private func environmentDeviceName(processInfo: ProcessInfo) -> String? {
        processInfo.environment[Self.deviceNameEnvironmentKey]
    }

    private func launchMode(processInfo: ProcessInfo) -> String? {
        let rawValue = processInfo.environment[Self.modeEnvironmentKey]
            ?? argumentValue(arguments: processInfo.arguments, name: Self.modeArgument)
        return nonEmptyValue(rawValue)?.lowercased()
    }

    private func argumentValue(arguments: [String], name: String) -> String? {
        guard let index = arguments.firstIndex(of: name) else {
            let prefix = "\(name)="
            return arguments.first(where: { $0.hasPrefix(prefix) })
                .map { String($0.dropFirst(prefix.count)) }
        }

        let nextIndex = arguments.index(after: index)
        guard arguments.indices.contains(nextIndex) else { return nil }
        return arguments[nextIndex]
    }

    private func nonEmptyValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
