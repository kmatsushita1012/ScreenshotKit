import Foundation

struct ProjectSettings: Sendable, Equatable {
    let projectPath: String
    let scheme: String
    let bundleID: String
    let fullProductName: String
    let executableName: String
}

struct DeviceDescriptor: Sendable, Equatable, Codable {
    let name: String
    let typeIdentifier: String
    let udid: String
}

struct SimulatorPlan: Sendable, Equatable {
    let runtimeID: String
    let iphone: DeviceDescriptor
    let ipad: DeviceDescriptor
}

struct DeviceInfo: Sendable, Equatable {
    let runtimeID: String
    let name: String
    let isAvailable: Bool
}

struct ManifestInfo: Sendable, Equatable {
    let sessionDirectoryPath: String
    let manifestPath: String
    let outputManifestPath: String
}

struct ScreenshotManifest: Sendable, Equatable, Codable {
    let deviceName: String
    let sessionDirectoryPath: String
    var entries: [ScreenshotManifestEntry]
    let completedAt: Date?
}

struct ScreenshotManifestEntry: Sendable, Equatable, Codable, Identifiable {
    let sceneID: String
    let localeIdentifier: String
    var outputIdentifier: String
    var relativePath: String?

    var id: String {
        "\(localeIdentifier)::\(outputIdentifier)"
    }
}
