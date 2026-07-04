//
//  BuiltinScreenshotStyles.swift
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
            let deviceKind = ScreenshotDeviceKind.current
            let screenHeight = ScreenshotPreviewLayoutMetrics.currentScreenHeight(
                fallbackHeight: proxy.size.height
            )
            let previewVerticalCompensation = ScreenshotPreviewLayoutMetrics.verticalCompensation(
                isRunningForPreview: ScreenshotPreviewLayoutMetrics.isRunningForPreview(),
                deviceKind: deviceKind,
                topSafeAreaInset: proxy.safeAreaInsets.top
            )

            ScreenshotDeviceScreenView(
                screenshotContent: configuration.screenshotContent
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scaleEffect(0.7)
            .offset(x: 0, y: proxy.size.height * 0.1)
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    configuration.title
                        .multilineTextAlignment(.center)
                    configuration.subtitle
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .offset(
                    x: 0,
                    y: ScreenshotPreviewLayoutMetrics.titleSubtitleVerticalOffset(
                        for: deviceKind,
                        screenHeight: screenHeight,
                        topSafeAreaInset: proxy.safeAreaInsets.top
                    )
                )
            }
            .offset(x: 0, y: previewVerticalCompensation)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        
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

enum ScreenshotPreviewLayoutMetrics {
    static let previewEnvironmentKey = "XCODE_RUNNING_FOR_PREVIEW"
    static let titleTopOffsetRatio: CGFloat = 46 / 956

    static func isRunningForPreview(processInfo: ProcessInfo = .processInfo) -> Bool {
        processInfo.environment[previewEnvironmentKey] == "1"
    }

    static func titleSubtitleVerticalOffset(
        for deviceKind: ScreenshotDeviceKind,
        screenHeight: CGFloat,
        topSafeAreaInset: CGFloat
    ) -> CGFloat {
        let baseTopOffset = max(
            topSafeAreaInset,
            screenHeight * titleTopOffsetRatio
        )

        return switch deviceKind {
        case .phone:
            baseTopOffset
        case .pad:
            baseTopOffset + screenHeight * titleTopOffsetRatio
        }
    }

    static func verticalCompensation(
        isRunningForPreview: Bool,
        deviceKind: ScreenshotDeviceKind,
        topSafeAreaInset: CGFloat
    ) -> CGFloat {
        guard isRunningForPreview, deviceKind == .phone else { return 0 }
        return +topSafeAreaInset
    }

    static func currentScreenHeight(fallbackHeight: CGFloat) -> CGFloat {
#if canImport(UIKit)
        return UIScreen.main.bounds.height
#else
        return fallbackHeight
#endif
    }
}
