//
//  ScreenshotStyle.swift
//  ScreenshotKit
//

import SwiftUI

public protocol ScreenshotStyle: Sendable {
    associatedtype Body: View

    @MainActor
    @ViewBuilder
    func makeBody(configuration: ScreenshotStyleConfiguration) -> Body
}

public struct ScreenshotStyleConfiguration {
    public let title: AnyView
    public let subtitle: AnyView
    public let content: AnyView

    public init(title: AnyView, subtitle: AnyView, content: AnyView) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }
}

protocol ResolvedScreenshotStyleIdentifying {
    var resolvedStyleIdentifier: String { get }
}

public struct AnyScreenshotStyle: ScreenshotStyle {
    private let makeBodyClosure: @MainActor (ScreenshotStyleConfiguration) -> AnyView
    let resolvedStyleIdentifier: String?

    public init<S: ScreenshotStyle>(_ style: S) {
        self.makeBodyClosure = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
        self.resolvedStyleIdentifier = (style as? any ResolvedScreenshotStyleIdentifying)?.resolvedStyleIdentifier
    }

    @MainActor
    public func makeBody(configuration: ScreenshotStyleConfiguration) -> some View {
        makeBodyClosure(configuration)
    }
}

extension EnvironmentValues {
    @Entry var screenshotStyle: AnyScreenshotStyle = AnyScreenshotStyle(DefaultScreenshotStyle())
}

public extension View {
    func screenshotStyle<S: ScreenshotStyle>(_ style: S) -> some View {
        environment(\.screenshotStyle, AnyScreenshotStyle(style))
    }
}

public extension ScreenshotStyle where Self == HeroScreenshotStyle {
    static var hero: HeroScreenshotStyle { HeroScreenshotStyle() }
}

public extension ScreenshotStyle where Self == DefaultScreenshotStyle {
    static var `default`: DefaultScreenshotStyle { DefaultScreenshotStyle() }
}
