import Foundation

public enum ScreenshotCommand: Sendable, Equatable, Hashable {
    case start(deviceName: String)
}
