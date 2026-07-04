//
//  ScreenshotView+Initializers.swift
//  ScreenshotKit
//

import SwiftUI

public extension ScreenshotView where Background == EmptyView, Title == AnyView, Subtitle == AnyView {
    init<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: {
                AnyView(
                    Text(title)
                        .font(ScreenshotDefaultTextStyle.titleFont)
                        .fontWeight(.bold)
                )
            },
            subtitle: {
                AnyView(
                    Text(subtitle)
                        .font(ScreenshotDefaultTextStyle.subtitleFont)
                        .foregroundStyle(.secondary)
                )
            },
            content: content
        )
    }
}

private enum ScreenshotDefaultTextStyle {
    static var titleFont: Font {
        switch ScreenshotDeviceKind.current {
        case .phone:
            .largeTitle
        case .pad:
            .system(size: 64, weight: .bold)
        }
    }

    static var subtitleFont: Font {
        switch ScreenshotDeviceKind.current {
        case .phone:
            .title3
        case .pad:
            .system(size: 34, weight: .regular)
        }
    }
}

public extension ScreenshotView where Background == EmptyView, Title == AnyView, Subtitle == AnyView {
    init(
        title: String,
        subtitle: String,
        image: ScreenshotImage,
        imageBundle: Bundle? = .main
    ) {
        self.init(
            title: {
                AnyView(
                    Text(title)
                        .font(ScreenshotDefaultTextStyle.titleFont)
                        .fontWeight(.bold)
                )
            },
            subtitle: {
                AnyView(
                    Text(subtitle)
                        .font(ScreenshotDefaultTextStyle.subtitleFont)
                        .foregroundStyle(.secondary)
                )
            },
            screenshotContent: {
                .image(
                    assetName: image.assetName(for: ScreenshotDeviceKind.current),
                    bundle: imageBundle
                )
            }
        )
    }

    @available(*, deprecated, message: "Use init(title:subtitle:image:imageBundle:) with ScreenshotImage.")
    init(
        title: String,
        subtitle: String,
        image assetName: String,
        imageBundle: Bundle? = .main
    ) {
        self.init(
            title: {
                AnyView(
                    Text(title)
                        .font(ScreenshotDefaultTextStyle.titleFont)
                        .fontWeight(.bold)
                )
            },
            subtitle: {
                AnyView(
                    Text(subtitle)
                        .font(ScreenshotDefaultTextStyle.subtitleFont)
                        .foregroundStyle(.secondary)
                )
            },
            screenshotContent: {
                .image(
                    assetName: assetName,
                    bundle: imageBundle
                )
            }
        )
    }
}

public extension ScreenshotView where Background == EmptyView, Title == EmptyView, Subtitle == EmptyView {
    init(
        image: ScreenshotImage,
        imageBundle: Bundle? = .main
    ) {
        self.init(
            title: { EmptyView() },
            subtitle: { EmptyView() },
            screenshotContent: {
                .image(
                    assetName: image.assetName(for: ScreenshotDeviceKind.current),
                    bundle: imageBundle
                )
            }
        )
    }

    @available(*, deprecated, message: "Use init(image:imageBundle:) with ScreenshotImage.")
    init(
        image assetName: String,
        imageBundle: Bundle? = .main
    ) {
        self.init(
            title: { EmptyView() },
            subtitle: { EmptyView() },
            screenshotContent: {
                .image(
                    assetName: assetName,
                    bundle: imageBundle
                )
            }
        )
    }
}
