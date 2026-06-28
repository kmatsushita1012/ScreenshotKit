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
                screenshotWrappedContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .safeAreaInset(edge: .top){
                        Capsule(style: .continuous)
                            .frame(width: 100, height: 30)
                            .padding(.top)
                            .frame(alignment: .top)
                    }
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

    @ViewBuilder
    private var screenshotWrappedContent: some View {
#if canImport(UIKit)
        ScreenshotContentViewControllerWrapper(
            content: contentBuilder
        )
#else
        contentBuilder()
#endif
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

private struct ScreenshotContentViewControllerWrapper<Content: View>: UIViewControllerRepresentable {
    let content: () -> Content

    func makeUIViewController(context: Context) -> ScreenshotContentContainerViewController<Content> {
        ScreenshotContentContainerViewController(rootView: content())
    }

    func updateUIViewController(
        _ uiViewController: ScreenshotContentContainerViewController<Content>,
        context: Context
    ) {
        uiViewController.update(rootView: content())
    }
}

private final class ScreenshotContentContainerViewController<Content: View>: UIViewController {
    private let hostingController: UIHostingController<Content>

    init(rootView: Content) {
        hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        hostingController.view.backgroundColor = .clear

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        configureNavigationBarIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hostingController.view.frame = view.bounds
    }

    func update(rootView: Content) {
        hostingController.rootView = rootView
    }

    private func configureNavigationBarIfNeeded() {
        guard let navigationBar = hostingController.view.firstSubview(of: UINavigationBar.self) else {
            return
        }

        navigationBar.isTranslucent = false
        navigationBar.backgroundColor = .clear
    }
}

private extension UIView {
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let view = self as? T {
            return view
        }

        for subview in subviews {
            if let match = subview.firstSubview(of: type) {
                return match
            }
        }

        return nil
    }
}
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
        VStack {
            Text("Hello, World!")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.mint)
        .toolbar{
            EditButton()
        }
    }
}
