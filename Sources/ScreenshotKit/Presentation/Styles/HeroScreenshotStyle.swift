//
//  HeroScreenshotStyle.swift
//  ScreenshotKit
//

import SwiftUI

public struct HeroScreenshotStyle: ScreenshotStyle {
    public init() {}

    @MainActor
    public func makeBody(configuration: ScreenshotStyleConfiguration) -> some View {
        GeometryReader { proxy in
            ScreenshotDeviceScreenView(
                screenshotContent: configuration.screenshotContent
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scaleEffect(deviceScale)
            .offset(x: 0, y: proxy.size.height * deviceVerticalOffsetRatio)
            .overlay(alignment: .top) {
                // proxy.size.height は safe area を含むキャンバス全体の高さ。
                // 0.25H の領域を上端に置き、その中心を 0.125H に固定する。
                textContent(configuration: configuration)
                    .frame(maxWidth: .infinity)
                    .frame(height: proxy.size.height * Self.textRegionHeightRatio)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private func textContent(configuration: ScreenshotStyleConfiguration) -> some View {
        VStack(spacing: titleSubtitleSpacing) {
            configuration.title
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
            configuration.subtitle
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, titleSubtitleHorizontalPadding)
    }
}

private extension HeroScreenshotStyle {
    static let textRegionHeightRatio: CGFloat = 0.25
}

public extension ScreenshotStyle where Self == HeroScreenshotStyle {
    static var hero: HeroScreenshotStyle { HeroScreenshotStyle() }
}

extension HeroScreenshotStyle: ResolvedScreenshotStyleIdentifying {
    var resolvedStyleIdentifier: String { "hero" }
}
