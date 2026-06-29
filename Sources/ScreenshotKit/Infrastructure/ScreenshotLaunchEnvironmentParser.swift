import Foundation

public protocol ScreenshotLaunchEnvironmentParserProtocol: Sendable {
    func parse(processInfo: ProcessInfo) -> ScreenshotRoute?
}

public struct ScreenshotLaunchEnvironmentParser: ScreenshotLaunchEnvironmentParserProtocol, Sendable {
    public static let autoStartEnvironmentKey = "SCREENSHOTKIT_AUTOSTART"
    public static let deviceNameEnvironmentKey = "SCREENSHOTKIT_DEVICE_NAME"
    public static let autoStartArgument = "--screenshotkit-autostart"
    public static let deviceNameArgument = "--screenshotkit-device-name"

    public init() {}

    public func parse(processInfo: ProcessInfo) -> ScreenshotRoute? {
        guard shouldAutoStart(processInfo: processInfo) else { return nil }

        let deviceName = environmentDeviceName(processInfo: processInfo)
            ?? argumentDeviceName(arguments: processInfo.arguments)

        return ScreenshotRoute(
            command: .start(deviceName: sanitizedDeviceName(deviceName))
        )
    }

    private func shouldAutoStart(processInfo: ProcessInfo) -> Bool {
        if let environmentValue = processInfo.environment[Self.autoStartEnvironmentKey] {
            return truthyValue(environmentValue)
        }

        return processInfo.arguments.contains(Self.autoStartArgument)
    }

    private func environmentDeviceName(processInfo: ProcessInfo) -> String? {
        processInfo.environment[Self.deviceNameEnvironmentKey]
    }

    private func argumentDeviceName(arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: Self.deviceNameArgument) else {
            let prefix = "\(Self.deviceNameArgument)="
            return arguments.first(where: { $0.hasPrefix(prefix) })
                .map { String($0.dropFirst(prefix.count)) }
        }

        let nextIndex = arguments.index(after: index)
        guard arguments.indices.contains(nextIndex) else { return nil }
        return arguments[nextIndex]
    }

    private func truthyValue(_ value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        default:
            return false
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
