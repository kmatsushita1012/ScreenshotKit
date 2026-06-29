//
//  HandleScreenshotCommandUseCase.swift
//  ScreenshotKit
//
//  Created by 松下和也 on 2026/06/14.
//

import Foundation

// MARK: - HandleScreenshotCommandUseCase
public protocol HandleScreenshotCommandUseCaseProtocol: Sendable {
    func execute(
        command: ScreenshotCommand,
        items: [ScreenshotDescriptor]
    ) async throws -> ScreenshotProgress
}

public struct HandleScreenshotCommandUseCase: HandleScreenshotCommandUseCaseProtocol {
    private let progressStore: any ScreenshotProgressStoreProtocol
    private let localeProvider: any ScreenshotLocaleProviderProtocol

    public init(
        progressStore: any ScreenshotProgressStoreProtocol,
        localeProvider: any ScreenshotLocaleProviderProtocol
    ) {
        self.progressStore = progressStore
        self.localeProvider = localeProvider
    }

    public func execute(
        command: ScreenshotCommand,
        items: [ScreenshotDescriptor]
    ) async throws -> ScreenshotProgress {
        switch command {
        case let .manifest(deviceName):
            let sessionDirectoryURL = try await progressStore.createSession(deviceName: deviceName)
            let localeIdentifiers = localeProvider.localeIdentifiers()
            let entries = localeIdentifiers.flatMap { localeIdentifier in
                items.map {
                    ScreenshotManifestEntry(
                        sceneID: $0.id,
                        localeIdentifier: localeIdentifier,
                        outputIdentifier: $0.fallbackOutputIdentifier,
                        relativePath: nil
                    )
                }
            }

            let manifest = ScreenshotManifest(
                deviceName: deviceName,
                sessionDirectoryPath: sessionDirectoryURL.path,
                entries: entries,
                completedAt: nil
            )

            guard !entries.isEmpty else {
                return ScreenshotProgress(
                    mode: .manifest,
                    current: nil,
                    pending: [],
                    finished: true,
                    sessionDirectoryPath: sessionDirectoryURL.path,
                    completedCount: 0,
                    totalCount: 0,
                    deviceName: deviceName,
                    manifest: manifest
                )
            }

            return ScreenshotProgress(
                mode: .manifest,
                current: nil,
                pending: [],
                finished: true,
                sessionDirectoryPath: sessionDirectoryURL.path,
                completedCount: entries.count,
                totalCount: entries.count,
                deviceName: deviceName,
                manifest: manifest
            )
        case let .capture(deviceName, sceneID, localeIdentifier, sessionDirectoryPath):
            guard let item = items.first(where: { $0.id == sceneID }) else {
                throw ScreenshotKitError.unknownSceneIdentifier(sceneID)
            }

            return ScreenshotProgress(
                mode: .capture,
                current: ScreenshotCaptureJob(
                    sceneID: sceneID,
                    localeIdentifier: localeIdentifier,
                    fallbackOutputIdentifier: item.fallbackOutputIdentifier
                ),
                pending: [],
                finished: false,
                sessionDirectoryPath: sessionDirectoryPath,
                completedCount: 0,
                totalCount: 1,
                deviceName: deviceName,
                manifest: nil
            )
        }
    }
}
