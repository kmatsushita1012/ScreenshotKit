import Foundation

public struct ScreenshotManifest: Sendable, Equatable, Codable, Hashable {
    public let deviceName: String
    public let sessionDirectoryPath: String
    public let entries: [ScreenshotManifestEntry]
    public let completedAt: Date

    public init(
        deviceName: String,
        sessionDirectoryPath: String,
        entries: [ScreenshotManifestEntry],
        completedAt: Date
    ) {
        self.deviceName = deviceName
        self.sessionDirectoryPath = sessionDirectoryPath
        self.entries = entries
        self.completedAt = completedAt
    }
}

public struct ScreenshotManifestEntry: Sendable, Equatable, Codable, Hashable, Identifiable {
    public let sceneID: String
    public let localeIdentifier: String
    public let outputIdentifier: String
    public let relativePath: String

    public var id: String {
        "\(localeIdentifier)::\(outputIdentifier)"
    }

    public init(
        sceneID: String,
        localeIdentifier: String,
        outputIdentifier: String,
        relativePath: String
    ) {
        self.sceneID = sceneID
        self.localeIdentifier = localeIdentifier
        self.outputIdentifier = outputIdentifier
        self.relativePath = relativePath
    }
}
