//
//  File.swift
//  ScreenshotKit
//
//  Created by 松下和也 on 2026/06/14.
//

import Foundation

public struct ScreenshotProgress: Sendable, Equatable, Codable, Hashable {
    public let current: ScreenshotCaptureJob?
    public let pending: [ScreenshotCaptureJob]
    public let finished: Bool
    public let sessionDirectoryPath: String?
    public let completedCount: Int
    public let totalCount: Int
    public let deviceName: String

    public init(
        current: ScreenshotCaptureJob?,
        pending: [ScreenshotCaptureJob],
        finished: Bool,
        sessionDirectoryPath: String?,
        completedCount: Int,
        totalCount: Int,
        deviceName: String
    ) {
        self.current = current
        self.pending = pending
        self.finished = finished
        self.sessionDirectoryPath = sessionDirectoryPath
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.deviceName = deviceName
    }
}
