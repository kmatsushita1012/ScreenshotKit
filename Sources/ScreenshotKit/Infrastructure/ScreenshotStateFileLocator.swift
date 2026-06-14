//
//  ScreenshotStateFileLocator.swift
//  ScreenshotKit
//
//  Infra: Application Support path resolver
//

import Foundation

public protocol ScreenshotStateFileLocatorProtocol: Sendable {
    func sessionsDirectoryURL() throws -> URL
    func latestSessionPointerURL() throws -> URL
}

public struct ScreenshotStateFileLocator: ScreenshotStateFileLocatorProtocol, Sendable {
    public init() {}

    public func sessionsDirectoryURL() throws -> URL {
        let fm = FileManager.default
        let urls = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let base = urls.first else {
            throw NSError(domain: "ScreenshotKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Application Support directory not found"])
        }

        let root = base
            .appendingPathComponent("ScreenshotKit", isDirectory: true)
            .appendingPathComponent("Sessions", isDirectory: true)

        if !fm.fileExists(atPath: root.path) {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
        }

        return root
    }

    public func latestSessionPointerURL() throws -> URL {
        try sessionsDirectoryURL()
            .appendingPathComponent("latest-session.txt")
    }
}
