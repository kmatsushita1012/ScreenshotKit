//
//  ScreenshotRoute.swift.swift
//  ScreenshotKit
//
//  Created by 松下和也 on 2026/06/14.
//
import Foundation

public struct ScreenshotRoute: Sendable, Equatable, Hashable {
    public let command: ScreenshotCommand

    public init(command: ScreenshotCommand) {
        self.command = command
    }
}
