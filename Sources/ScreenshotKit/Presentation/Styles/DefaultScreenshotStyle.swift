//
//  DefaultScreenshotStyle.swift
//  ScreenshotKit
//

import SwiftUI

public struct DefaultScreenshotStyle: ScreenshotStyle {
    private let heroStyle = HeroScreenshotStyle()

    public init() {}

    @MainActor
    public func makeBody(configuration: ScreenshotStyleConfiguration) -> some View {
        heroStyle.makeBody(configuration: configuration)
    }
}

public extension ScreenshotStyle where Self == DefaultScreenshotStyle {
    static var `default`: DefaultScreenshotStyle { DefaultScreenshotStyle() }
}

extension DefaultScreenshotStyle: ResolvedScreenshotStyleIdentifying {
    var resolvedStyleIdentifier: String { "hero" }
}
