//
//  ValidateScreenshotItemsUseCase.swift
//  ScreenshotKit
//
//  Created by 松下和也 on 2026/06/14.
//

// MARK: - ValidateScreenshotItemsUseCase

public protocol ValidateScreenshotItemsUseCaseProtocol: Sendable {
    func execute(items: [ScreenshotDescriptor]) throws
}

public struct ValidateScreenshotItemsUseCase: ValidateScreenshotItemsUseCaseProtocol {
    public init() {}

    public func execute(items: [ScreenshotDescriptor]) throws {
        var idSet = Set<String>()

        for item in items {
            if item.id.isEmpty { throw ScreenshotKitError.emptyIdentifier }
            if item.fallbackOutputIdentifier.isEmpty { throw ScreenshotKitError.fileWriteFailed }

            if !idSet.insert(item.id).inserted {
                throw ScreenshotKitError.duplicateIdentifier(item.id)
            }
        }
    }
}
