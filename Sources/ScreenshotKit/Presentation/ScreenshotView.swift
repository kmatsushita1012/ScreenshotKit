//
//  ScreenshotView.swift
//  ScreenshotKit
//

import SwiftUI

public struct ScreenshotView<Title: View, Subtitle: View, Content: View, Background: View>: View {
    @Environment(\.screenshotStyle) private var currentStyle

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
        currentStyle.makeBody(
            configuration: ScreenshotStyleConfiguration(
                title: AnyView(titleView()),
                subtitle: AnyView(subtitleView()),
                content: AnyView(contentBuilder())
            )
        )
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

#Preview {
    ScreenshotView(title: "とても賢いアプリです", subtitle: "ダウンロード必須ダウンロード必須") {
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
