//
//  ScreenshotDescriptor.swift
//  ScreenshotKit
//
//  Created by 松下和也 on 2026/06/14.
//

import Foundation

public struct ScreenshotDescriptor: Sendable, Equatable, Codable, Hashable, Identifiable {
    public let id: String

    public var identifier: String { id }

    public init(id: String) {
        self.id = id
    }
}
