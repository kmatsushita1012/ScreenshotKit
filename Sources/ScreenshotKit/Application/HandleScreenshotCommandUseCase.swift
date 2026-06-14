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
        case let .start(deviceName):
            let sessionDirectoryURL = try await progressStore.createSession(deviceName: deviceName)
            let localeIdentifiers = localeProvider.localeIdentifiers()
            let jobs = localeIdentifiers.flatMap { localeIdentifier in
                items.map {
                    ScreenshotCaptureJob(
                        sceneID: $0.id,
                        localeIdentifier: localeIdentifier,
                        fallbackOutputIdentifier: $0.fallbackOutputIdentifier
                    )
                }
            }

            guard let first = jobs.first else {
                try await progressStore.markFinished(
                    sessionDirectoryURL: sessionDirectoryURL,
                    manifest: ScreenshotManifest(
                        deviceName: deviceName,
                        sessionDirectoryPath: sessionDirectoryURL.path,
                        entries: [],
                        completedAt: Date()
                    )
                )
                return ScreenshotProgress(
                    current: nil,
                    pending: [],
                    finished: true,
                    sessionDirectoryPath: sessionDirectoryURL.path,
                    completedCount: 0,
                    totalCount: 0,
                    deviceName: deviceName
                )
            }

            return ScreenshotProgress(
                current: first,
                pending: Array(jobs.dropFirst()),
                finished: false,
                sessionDirectoryPath: sessionDirectoryURL.path,
                completedCount: 0,
                totalCount: jobs.count,
                deviceName: deviceName
            )
        }
    }
}
