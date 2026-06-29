import Foundation

public enum ScreenshotCommand: Sendable, Equatable, Hashable {
    case manifest(deviceName: String)
    case capture(
        deviceName: String,
        sceneID: String,
        localeIdentifier: String,
        sessionDirectoryPath: String
    )
}
