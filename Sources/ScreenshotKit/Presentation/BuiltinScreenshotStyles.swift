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
                        for: deviceKind
                    ) + 46
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
    static let referencePhoneStatusBarHeight: CGFloat = 46
    static let referencePhoneScreenHeight: CGFloat = 956
    static let referencePadScreenHeight: CGFloat = 1376

    static func isRunningForPreview(processInfo: ProcessInfo = .processInfo) -> Bool {
        processInfo.environment[previewEnvironmentKey] == "1"
    }

    static func titleSubtitleVerticalOffset(for deviceKind: ScreenshotDeviceKind) -> CGFloat {
        switch deviceKind {
        case .phone:
            0
        case .pad:
            referencePhoneStatusBarHeight * (currentScreenHeight(for: deviceKind) / referencePhoneScreenHeight)
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

    static func currentScreenHeight(for deviceKind: ScreenshotDeviceKind) -> CGFloat {
#if canImport(UIKit)
        if ScreenshotDeviceKind.current == deviceKind {
            return UIScreen.main.bounds.height
        }
#endif
        return switch deviceKind {
        case .phone:
            referencePhoneScreenHeight
        case .pad:
            referencePadScreenHeight
        }
    }
}
