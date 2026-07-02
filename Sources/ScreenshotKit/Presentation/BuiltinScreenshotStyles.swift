//
//  BuiltinScreenshotStyles.swift
//  ScreenshotKit
//

import SwiftUI

public struct HeroScreenshotStyle: ScreenshotStyle {
    public init() {}

    @MainActor
    public func makeBody(configuration: ScreenshotStyleConfiguration) -> some View {
        GeometryReader { proxy in
            let previewVerticalCompensation = ScreenshotPreviewLayoutMetrics.verticalCompensation(
                isRunningForPreview: ScreenshotPreviewLayoutMetrics.isRunningForPreview(),
                deviceKind: ScreenshotDeviceKind.current,
                topSafeAreaInset: proxy.safeAreaInsets.top
            )

            ScreenshotDeviceScreenView {
                configuration.content
            }
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
                .offset(x: 0, y: proxy.size.height * 0.05)
            }
            .offset(x: 0, y: previewVerticalCompensation)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    static func isRunningForPreview(processInfo: ProcessInfo = .processInfo) -> Bool {
        processInfo.environment[previewEnvironmentKey] == "1"
    }

    static func verticalCompensation(
        isRunningForPreview: Bool,
        deviceKind: ScreenshotDeviceKind,
        topSafeAreaInset: CGFloat
    ) -> CGFloat {
        guard isRunningForPreview, deviceKind == .phone else { return 0 }
        return +topSafeAreaInset
    }
}
