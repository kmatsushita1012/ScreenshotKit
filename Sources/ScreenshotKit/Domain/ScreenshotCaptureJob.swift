import Foundation

public struct ScreenshotCaptureJob: Sendable, Equatable, Codable, Hashable, Identifiable {
    public let sceneID: String
    public let localeIdentifier: String
    public let fallbackOutputIdentifier: String

    public var id: String {
        "\(localeIdentifier)::\(sceneID)"
    }

    public init(
        sceneID: String,
        localeIdentifier: String,
        fallbackOutputIdentifier: String
    ) {
        self.sceneID = sceneID
        self.localeIdentifier = localeIdentifier
        self.fallbackOutputIdentifier = fallbackOutputIdentifier
    }
}
