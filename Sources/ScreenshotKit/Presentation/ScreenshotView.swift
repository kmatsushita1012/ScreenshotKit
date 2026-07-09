//
//  ScreenshotView.swift
//  ScreenshotKit
//

import SwiftUI

public struct ScreenshotView<Title: View, Subtitle: View, Background: View>: View {
    @Environment(\.screenshotStyle) private var currentStyle

    private let titleView: () -> Title
    private let subtitleView: () -> Subtitle
    private let screenshotContentBuilder: () -> ScreenshotContent

    public init<Content: View>(
        @ViewBuilder title: @escaping () -> Title,
        @ViewBuilder subtitle: @escaping () -> Subtitle,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            screenshotContent: {
                .view(AnyView(content()))
            }
        )
    }

    init(
        @ViewBuilder title: @escaping () -> Title,
        @ViewBuilder subtitle: @escaping () -> Subtitle,
        screenshotContent: @escaping () -> ScreenshotContent
    ) {
        self.titleView = title
        self.subtitleView = subtitle
        self.screenshotContentBuilder = screenshotContent
    }

    public var body: some View {
        currentStyle.makeBody(
            configuration: ScreenshotStyleConfiguration(
                title: AnyView(titleView()),
                subtitle: AnyView(subtitleView()),
                screenshotContent: screenshotContentBuilder()
            )
        )
        .preference(
            key: ScreenshotSceneRenderedPreferenceKey.self,
            value: true
        )
    }
}

struct ScreenshotSceneRenderedPreferenceKey: PreferenceKey {
    static var defaultValue: Bool { false }

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

#if os(iOS)
    #Preview {
        ScreenshotView(
            title: "とても賢いアプリです",
            subtitle: "ダウンロード必須ダウンロード必須"
        ) {
            VStack {
                Text("Hello, World!")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.mint)
            .navigationTitle("Hello")
            .toolbar {
                EditButton()
            }
        }
        .screenshotStyle(.hero)
    }
#endif
