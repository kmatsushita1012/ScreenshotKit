//
//  ScreenshotView.swift
//  ScreenshotKit
//

import SwiftUI

public struct ScreenshotView<Title: View, Subtitle: View, Content: View, Background: View>: View {
    private let outputIdentifier: String?
    private let titleView: () -> Title
    private let subtitleView: () -> Subtitle
    private let contentBuilder: () -> Content

    public init(
        id: String? = nil,
        @ViewBuilder title: @escaping () -> Title,
        @ViewBuilder subtitle: @escaping () -> Subtitle,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.outputIdentifier = id
        self.titleView = title
        self.subtitleView = subtitle
        self.contentBuilder = content
    }

    public var body: some View {
        GeometryReader { proxy in
            let previewVerticalCompensation = ScreenshotPreviewLayoutMetrics.verticalCompensation(
                isRunningForPreview: ScreenshotPreviewLayoutMetrics.isRunningForPreview(),
                topSafeAreaInset: proxy.safeAreaInsets.top
            )

            ScreenshotDeviceScreenView(
                content: contentBuilder
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scaleEffect(0.7)
            .offset(x: 0, y: proxy.size.height * 0.1)

            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    titleView()
                        .multilineTextAlignment(.center)
                    subtitleView()
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .offset(x: 0, y: proxy.size.height * 0.05)
            }
            .offset(x: 0, y: previewVerticalCompensation)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preference(
            key: ScreenshotOutputIdentifierPreferenceKey.self,
            value: outputIdentifier
        )
    }
}

struct ScreenshotOutputIdentifierPreferenceKey: PreferenceKey {
    static var defaultValue: String? { nil }

    static func reduce(value: inout String?, nextValue: () -> String?) {
        value = nextValue() ?? value
    }
}

enum ScreenshotPreviewLayoutMetrics {
    static let previewEnvironmentKey = "XCODE_RUNNING_FOR_PREVIEW"

    static func isRunningForPreview(processInfo: ProcessInfo = .processInfo) -> Bool {
        processInfo.environment[previewEnvironmentKey] == "1"
    }

    static func verticalCompensation(
        isRunningForPreview: Bool,
        topSafeAreaInset: CGFloat
    ) -> CGFloat {
        guard isRunningForPreview else { return 0 }
        return +topSafeAreaInset
    }
}

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
                        .font(.largeTitle)
                        .fontWeight(.bold)
                )
            },
            subtitle: {
                AnyView(
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                )
            },
            content: content
        )
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


#Preview {
    ScreenshotView(title: "とても賢いアプリです", subtitle: "ダウンロード必須ダウンロード必須"){
        VStack {
            Text("Hello, World!")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.mint)
        .navigationTitle("Hello")
        .toolbar{
            EditButton()
        }
    }
}
