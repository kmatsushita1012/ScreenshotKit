//
//  DeviceBottomScreenshotStyle.swift
//  ScreenshotKit
//

import SwiftUI

public struct DeviceBottomScreenshotStyle: ScreenshotStyle {
    public init() {}

    public var deviceScale: CGFloat { 0.8 }

    @MainActor
    public func makeBody(configuration: ScreenshotStyleConfiguration) -> some View {
        GeometryReader { proxy in
            deviceViewport(
                configuration: configuration,
                proxy: proxy,
                deviceOffsetRatio: deviceOffsetRatio
            )
            // scaleEffect は見た目だけを変え、レイアウト上の frame は変えない。
            // そのため、デバイスとテキストを VStack で平面配置すると、
            // 変形後のデバイスが隣接領域へはみ出して位置が崩れる。
            .overlay(alignment: .bottom) {
                textContent(configuration: configuration)
                    .frame(maxWidth: .infinity)
                    .frame(height: proxy.size.height * Self.textRegionRatio)
                    // 下端基準の 0.2H の箱の中心は 0.9H。中心を 0.8H に置くため、
                    // 箱の半分の高さだけ上へ補正する。
                    .offset(y: -proxy.size.height * Self.textCenterOffsetRatio)
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, titleSubtitleHorizontalPadding)
    }

    @MainActor
    private func deviceViewport(
        configuration: ScreenshotStyleConfiguration,
        proxy: GeometryProxy,
        deviceOffsetRatio: CGFloat
    ) -> some View {
        ZStack {
            ScreenshotDeviceScreenView(
                screenshotContent: configuration.screenshotContent
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scaleEffect(deviceScale)
            .offset(y: proxy.size.height * deviceOffsetRatio)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension DeviceBottomScreenshotStyle {
    static let textRegionRatio: CGFloat = 0.2
    static let textCenterOffsetRatio: CGFloat = textRegionRatio / 2

    var deviceOffsetRatio: CGFloat {
        -((1 - deviceVisibleHeightRatio) - (1 - deviceScale) / 2)
    }
}

public extension ScreenshotStyle where Self == DeviceBottomScreenshotStyle {
    static var deviceBottom: DeviceBottomScreenshotStyle { DeviceBottomScreenshotStyle() }
}

extension DeviceBottomScreenshotStyle: ResolvedScreenshotStyleIdentifying {
    var resolvedStyleIdentifier: String { "device-bottom" }
}
