import Foundation

public struct ScreenshotCaptureJob: Sendable, Equatable, Codable, Hashable, Identifiable {
    public let sceneID: String
    public let localeIdentifier: String

    public var id: String {
        "\(localeIdentifier)::\(sceneID)"
    }

    public var outputIdentifier: String {
        sceneID
    }

    public init(
        sceneID: String,
        localeIdentifier: String
    ) {
        self.sceneID = sceneID
        self.localeIdentifier = localeIdentifier
    }
}
