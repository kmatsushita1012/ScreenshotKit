import Foundation

public enum ScreenshotKitError: Error, Sendable, Equatable {
    case invalidURL
    case unsupportedCommand
    case duplicateIdentifier(String)
    case emptyIdentifier
    case fileWriteFailed
    case fileReadFailed
    case missingRenderView(String)
    case captureFailed
    case missingSessionDirectoryPath
    case unknownSceneIdentifier(String)
    case unsupportedPlatform
    case unknown
}
