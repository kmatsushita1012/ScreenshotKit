//
//  HeroScreenshotStyle.swift
//  ScreenshotKit
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct HeroScreenshotStyle: ScreenshotStyle {
    public init() {}

    @MainActor
    public func makeBody(configuration: ScreenshotStyleConfiguration) -> some View {
        GeometryReader { proxy in
            let screenHeight = Self.currentScreenHeight(
                fallbackHeight: proxy.size.height
            )
            let titleSubtitleVerticalOffset = Self.titleSubtitleVerticalOffset(
                deviceKind: deviceKind,
                screenHeight: screenHeight,
                topSafeAreaInset: proxy.safeAreaInsets.top,
                titleTopOffsetRatio: Self.titleTopOffsetRatio
            )
            let previewSafeAreaCompensation = Self.previewSafeAreaCompensation(
                isRunningForPreview: isRunningForPreview,
                deviceKind: deviceKind,
                topSafeAreaInset: proxy.safeAreaInsets.top
            )

            ScreenshotDeviceScreenView(
                screenshotContent: configuration.screenshotContent
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scaleEffect(deviceScale)
            .offset(x: 0, y: proxy.size.height * deviceVerticalOffsetRatio)
            .overlay(alignment: .top) {
                VStack(spacing: titleSubtitleSpacing) {
                    configuration.title
                        .multilineTextAlignment(.center)
                    configuration.subtitle
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, titleSubtitleHorizontalPadding)
                .offset(x: 0, y: titleSubtitleVerticalOffset)
            }
            .offset(x: 0, y: previewSafeAreaCompensation)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        
    }
}

private extension HeroScreenshotStyle {
    static let titleTopOffsetRatio: CGFloat = 46 / 956

    static func currentScreenHeight(fallbackHeight: CGFloat) -> CGFloat {
#if canImport(UIKit)
        return UIScreen.main.bounds.height
#else
        return fallbackHeight
#endif
    }

    static func titleSubtitleVerticalOffset(
        deviceKind: ScreenshotDeviceKind,
        screenHeight: CGFloat,
        topSafeAreaInset: CGFloat,
        titleTopOffsetRatio: CGFloat
    ) -> CGFloat {
        let baseTopOffset = max(topSafeAreaInset, screenHeight * titleTopOffsetRatio)

        switch deviceKind {
        case .phone:
            return baseTopOffset
        case .pad:
            return baseTopOffset + screenHeight * titleTopOffsetRatio
        }
    }

    static func previewSafeAreaCompensation(
        isRunningForPreview: Bool,
        deviceKind: ScreenshotDeviceKind,
        topSafeAreaInset: CGFloat
    ) -> CGFloat {
        guard isRunningForPreview, deviceKind == .phone else { return 0 }
        return topSafeAreaInset
    }
}

extension HeroScreenshotStyle: ResolvedScreenshotStyleIdentifying {
    var resolvedStyleIdentifier: String { "hero" }
}

public struct DefaultScreenshotStyle: ScreenshotStyle {
    private let heroStyle = HeroScreenshotStyle()

    public init() {}

    @MainActor
    public func makeBody(configuration: ScreenshotStyleConfiguration) -> some View {
        heroStyle.makeBody(configuration: configuration)
    }
}

extension DefaultScreenshotStyle: ResolvedScreenshotStyleIdentifying {
    var resolvedStyleIdentifier: String { "hero" }
}
