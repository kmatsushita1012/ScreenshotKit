//
//  ScreenshotView+Initializers.swift
//  ScreenshotKit
//

import SwiftUI

public extension ScreenshotView where Background == EmptyView, Title == AnyView, Subtitle == AnyView {
    init(
        id: String? = nil,
        title: String,
        subtitle: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            id: id,
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

public extension ScreenshotView where Background == EmptyView, Content == AnyView, Title == AnyView, Subtitle == AnyView {
    init(
        id: String? = nil,
        title: String,
        subtitle: String,
        image assetName: String,
        imageBundle: Bundle? = .main
    ) {
        self.init(
            id: id,
            title: title,
            subtitle: subtitle,
            content: {
                AnyView(
                    Image(assetName, bundle: imageBundle)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                )
            }
        )
    }
}

public extension ScreenshotView where Background == EmptyView, Content == AnyView, Title == EmptyView, Subtitle == EmptyView {
    init(
        id: String? = nil,
        image assetName: String,
        imageBundle: Bundle? = .main
    ) {
        self.init(
            id: id,
            title: { EmptyView() },
            subtitle: { EmptyView() },
            content: {
                AnyView(
                    Image(assetName, bundle: imageBundle)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                )
            }
        )
    }
}
