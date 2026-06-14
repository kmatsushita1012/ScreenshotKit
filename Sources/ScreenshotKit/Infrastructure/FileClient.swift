//
//  FileClient.swift
//  ScreenshotKit
//
//  Auto-generated Infrastructure component: File I/O client
//
import Foundation

public protocol FileClientProtocol: Sendable {
    func read(from url: URL) async throws -> Data
    func write(_ data: Data, to url: URL) async throws
    func write(_ string: String, to url: URL) async throws
    func fileExists(at url: URL) async -> Bool
    func createDirectory(at url: URL) async throws
    func removeItemIfExists(at url: URL) async throws
}

actor FileClient: FileClientProtocol {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func read(from url: URL) async throws -> Data {
        try await Task.detached(priority: nil) {
            try Data(contentsOf: url, options: [.mappedIfSafe])
        }.value
    }

    public func write(_ data: Data, to url: URL) async throws {
        try await Task.detached(priority: nil) {
            try data.write(to: url, options: [.atomic])
        }.value
    }

    public func write(_ string: String, to url: URL) async throws {
        try await write(Data(string.utf8), to: url)
    }

    public func fileExists(at url: URL) async -> Bool {
        self.fileManager.fileExists(atPath: url.path)
    }

    public func createDirectory(at url: URL) async throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func removeItemIfExists(at url: URL) async throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
