//
//  ScreenshotView.swift
//  ScreenshotKit
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
            ZStack{
                contentBuilder()
                    .frame(maxWidth: .infinity, maxHeight: .infinity,alignment: .center)
                Capsule(style: .continuous)
                    .frame(width: 100, height: 30)
                    .padding(.top)
                    .frame(maxHeight: .infinity,alignment: .top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(platformSystemBackgroundColor)
            .clipShape(roundedRectangle)
            .overlay(
                roundedRectangle
                    .stroke(platformBorderColor, lineWidth: 8)
            )
            .overlay(
                roundedRectangle
                    .stroke(.black, lineWidth: 4)
            )
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

private let roundedRectangle = RoundedRectangle(cornerRadius: 44, style: .continuous)
#if canImport(UIKit)
private let platformSystemBackgroundColor = Color(.systemBackground)
private let platformBorderColor = Color(uiColor: UIColor.darkGray)
#else
private let platformSystemBackgroundColor = Color.white
private let platformBorderColor = Color.gray
#endif

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
        NavigationStack {
            VStack {
                Text("Hello, World!")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.mint)
            .toolbar{
                ToolbarItem(placement: .cancellationAction) {
                    Button("close", systemImage: "xmark") {
                        print("")
                    }
                }
            }
            
        }
    }
}
