//
//  ScreenshotProgressStore.swift
//  ScreenshotKit
//

import Foundation

public protocol ScreenshotProgressStoreProtocol: Sendable {
    func createSession(deviceName: String) async throws -> URL
    func prepareForCapture(sessionDirectoryURL: URL) async throws
    func markCaptureReady(sessionDirectoryURL: URL, message: String) async throws
    func markFinished(
        sessionDirectoryURL: URL,
        manifest: ScreenshotManifest
    ) async throws
    func markFailed(sessionDirectoryURL: URL, message: String) async throws
}

public actor ScreenshotProgressStore: ScreenshotProgressStoreProtocol {
    private let fileClient: any FileClientProtocol
    private let stateFileLocator: any ScreenshotStateFileLocatorProtocol

    public init(
        fileClient: any FileClientProtocol,
        stateFileLocator: any ScreenshotStateFileLocatorProtocol
    ) {
        self.fileClient = fileClient
        self.stateFileLocator = stateFileLocator
    }

    public func createSession(deviceName: String) async throws -> URL {
        let sessionsDirectoryURL = try stateFileLocator.sessionsDirectoryURL()
        try await fileClient.createDirectory(at: sessionsDirectoryURL)

        let sessionDirectoryURL = sessionsDirectoryURL.appendingPathComponent(
            "session-\(Self.sessionTimestamp())",
            isDirectory: true
        )
        try await fileClient.createDirectory(at: sessionDirectoryURL)

        let latestSessionPointerURL = try stateFileLocator.latestSessionPointerURL()
        try await fileClient.write(sessionDirectoryURL.path, to: latestSessionPointerURL)

        let metadataURL = sessionDirectoryURL.appendingPathComponent("session.txt")
        try await fileClient.write(deviceName, to: metadataURL)

        let completeMarkerURL = sessionDirectoryURL.appendingPathComponent("capture-complete")
        try await fileClient.removeItemIfExists(at: completeMarkerURL)

        let errorMarkerURL = sessionDirectoryURL.appendingPathComponent("capture-error.txt")
        try await fileClient.removeItemIfExists(at: errorMarkerURL)

        return sessionDirectoryURL
    }

    public func prepareForCapture(sessionDirectoryURL: URL) async throws {
        let completeMarkerURL = sessionDirectoryURL.appendingPathComponent("capture-complete")
        try await fileClient.removeItemIfExists(at: completeMarkerURL)

        let errorMarkerURL = sessionDirectoryURL.appendingPathComponent("capture-error.txt")
        try await fileClient.removeItemIfExists(at: errorMarkerURL)
    }

    public func markCaptureReady(sessionDirectoryURL: URL, message: String) async throws {
        let markerURL = sessionDirectoryURL.appendingPathComponent("capture-complete")
        try await fileClient.write(message, to: markerURL)
    }

    public func markFinished(
        sessionDirectoryURL: URL,
        manifest: ScreenshotManifest
    ) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let manifestURL = sessionDirectoryURL.appendingPathComponent("manifest.json")
        let manifestData = try encoder.encode(manifest)
        try await fileClient.write(manifestData, to: manifestURL)

        let markerURL = sessionDirectoryURL.appendingPathComponent("capture-complete")
        try await fileClient.write("manifest-ready", to: markerURL)
    }

    public func markFailed(sessionDirectoryURL: URL, message: String) async throws {
        let markerURL = sessionDirectoryURL.appendingPathComponent("capture-error.txt")
        try await fileClient.write(message, to: markerURL)
    }

    private static func sessionTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter.string(from: Date())
    }
}
