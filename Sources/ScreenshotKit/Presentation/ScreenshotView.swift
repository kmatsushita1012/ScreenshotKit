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
        .ignoresSafeArea(.all)
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
    private let hostingController: UIHostingController<ScreenshotNavigationContainer<Content>>
    private var didConfigureNavigationBar = false
    private var didDumpScenes = false
    private var didDumpNavigationControllers = false
    private var didDumpViewControllers = false
    private var didLogOwnLocationAfterAppearance = false
    private var didDumpParentChainAfterAppearance = false
    private var didDumpPresentationViewHierarchyAfterAppearance = false

    init(rootView: Content) {
        hostingController = UIHostingController(
            rootView: ScreenshotNavigationContainer(content: rootView)
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        configureNavigationBarIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hostingController.view.frame = view.bounds
        configureNavigationBarIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        logOwnLocationAfterAppearanceIfNeeded()
        dumpParentChainAfterAppearanceIfNeeded()
        configureNavigationBarIfNeeded()
        dumpPresentationViewHierarchyAfterAppearanceIfNeeded()
    }

    func update(rootView: Content) {
        hostingController.rootView = ScreenshotNavigationContainer(content: rootView)
        didConfigureNavigationBar = false
    }

    private func configureNavigationBarIfNeeded() {
        dumpScenesIfNeeded()
        dumpNavigationControllersIfNeeded()
        dumpViewControllersIfNeeded()
        guard !didConfigureNavigationBar else { return }
        let verticalOffset: CGFloat = 44
        guard let presentationHostingController = nearestPresentationHostingController() else {
            return
        }

        guard let navigationBar = presentationHostingController.view.firstSubview(where: {
            NSStringFromClass(type(of: $0)).contains("UIKitNavigationBar")
        }) else {
            return
        }

        navigationBar.transform = CGAffineTransform(
            translationX: 0,
            y: verticalOffset
        )
        
        didConfigureNavigationBar = true
    }

    private func dumpScenesIfNeeded() {
        guard !didDumpScenes else { return }
        didDumpScenes = true

        let connectedScenes = UIApplication.shared.connectedScenes
        print("ScreenshotKit scene dump begin")
        print("ScreenshotKit connectedScenes.count=\(connectedScenes.count)")

        if connectedScenes.isEmpty {
            print("ScreenshotKit scene dump: no connected scenes")
        }

        for (sceneIndex, scene) in connectedScenes.enumerated() {
            let sceneAddress = String(describing: Unmanaged.passUnretained(scene).toOpaque())
            let activationState = describeActivationState(scene.activationState)
            print(
                "ScreenshotKit scene[\(sceneIndex)] \(NSStringFromClass(type(of: scene))) " +
                "\(sceneAddress) activation=\(activationState)"
            )

            guard let windowScene = scene as? UIWindowScene else {
                continue
            }

            for (windowIndex, window) in windowScene.windows.enumerated() {
                let windowAddress = String(describing: Unmanaged.passUnretained(window).toOpaque())
                let rootDescription = window.rootViewController.map {
                    NSStringFromClass(type(of: $0))
                } ?? "nil"
                print(
                    "ScreenshotKit scene[\(sceneIndex)] window[\(windowIndex)] " +
                    "\(NSStringFromClass(type(of: window))) \(windowAddress) " +
                    "isKey=\(window.isKeyWindow) hidden=\(window.isHidden) alpha=\(window.alpha) " +
                    "level=\(window.windowLevel.rawValue) root=\(rootDescription)"
                )
            }
        }

        let ownWindowAddress = view.window.map {
            String(describing: Unmanaged.passUnretained($0).toOpaque())
        } ?? "nil"
        let ownSceneAddress = view.window?.windowScene.map {
            String(describing: Unmanaged.passUnretained($0).toOpaque())
        } ?? "nil"
        let ownSceneDescription = view.window?.windowScene.map {
            NSStringFromClass(type(of: $0))
        } ?? "nil"
        print(
            "ScreenshotKit self location vc=\(NSStringFromClass(type(of: self))) " +
            "window=\(ownWindowAddress) scene=\(ownSceneDescription) \(ownSceneAddress)"
        )
        print("ScreenshotKit scene dump end")
    }

    private func logOwnLocationAfterAppearanceIfNeeded() {
        guard !didLogOwnLocationAfterAppearance else { return }
        didLogOwnLocationAfterAppearance = true

        let ownAddress = String(describing: Unmanaged.passUnretained(self).toOpaque())
        let ownWindowAddress = view.window.map {
            String(describing: Unmanaged.passUnretained($0).toOpaque())
        } ?? "nil"
        let ownSceneAddress = view.window?.windowScene.map {
            String(describing: Unmanaged.passUnretained($0).toOpaque())
        } ?? "nil"
        let ownSceneDescription = view.window?.windowScene.map {
            NSStringFromClass(type(of: $0))
        } ?? "nil"
        let parentDescription = parent.map {
            NSStringFromClass(type(of: $0))
        } ?? "nil"
        let navigationDescription = navigationController.map {
            NSStringFromClass(type(of: $0))
        } ?? "nil"

        print(
            "ScreenshotKit self appeared vc=\(NSStringFromClass(type(of: self))) \(ownAddress) " +
            "parent=\(parentDescription) nav=\(navigationDescription) " +
            "window=\(ownWindowAddress) scene=\(ownSceneDescription) \(ownSceneAddress)"
        )
    }

    private func dumpParentChainAfterAppearanceIfNeeded() {
        guard !didDumpParentChainAfterAppearance else { return }
        didDumpParentChainAfterAppearance = true

        print("ScreenshotKit parent chain dump begin")

        var current: UIViewController? = self
        var index = 0
        while let viewController = current {
            let address = String(describing: Unmanaged.passUnretained(viewController).toOpaque())
            let parentDescription = viewController.parent.map {
                NSStringFromClass(type(of: $0))
            } ?? "nil"
            let navigationDescription = viewController.navigationController.map {
                NSStringFromClass(type(of: $0))
            } ?? "nil"
            let presentedDescription = viewController.presentedViewController.map {
                NSStringFromClass(type(of: $0))
            } ?? "nil"
            let childrenCount = viewController.children.count

            print(
                "ScreenshotKit parent[\(index)] \(NSStringFromClass(type(of: viewController))) \(address) " +
                "parent=\(parentDescription) nav=\(navigationDescription) " +
                "presented=\(presentedDescription) children=\(childrenCount)"
            )

            current = viewController.parent
            index += 1
        }

        print("ScreenshotKit parent chain dump end")
    }

    private func dumpPresentationViewHierarchyAfterAppearanceIfNeeded() {
        guard !didDumpPresentationViewHierarchyAfterAppearance else { return }
        didDumpPresentationViewHierarchyAfterAppearance = true

        guard let presentationParent = nearestPresentationHostingController() else {
            print("ScreenshotKit presentation view dump: parent presentation host not found")
            return
        }

        let address = String(describing: Unmanaged.passUnretained(presentationParent).toOpaque())
        print(
            "ScreenshotKit presentation view dump begin " +
            "\(NSStringFromClass(type(of: presentationParent))) \(address)"
        )

        var visited = Set<ObjectIdentifier>()
        dumpViewTree(
            presentationParent.view,
            indent: 0,
            visited: &visited
        )

        print("ScreenshotKit presentation view dump end")
    }

    private func nearestPresentationHostingController() -> UIViewController? {
        var current: UIViewController? = self
        while let viewController = current {
            if NSStringFromClass(type(of: viewController)).contains("PresentationHostingController") {
                return viewController
            }
            current = viewController.parent
        }
        return nil
    }

    private func dumpNavigationControllersIfNeeded() {
        guard !didDumpNavigationControllers else { return }
        didDumpNavigationControllers = true

        let navigationControllers = allNavigationControllersInApplication()
        print("ScreenshotKit navigation controller dump begin")

        if navigationControllers.isEmpty {
            print("ScreenshotKit navigation controller dump: none found")
        }

        for (index, navigationController) in navigationControllers.enumerated() {
            let address = String(describing: Unmanaged.passUnretained(navigationController).toOpaque())
            let stackDescription = navigationController.viewControllers
                .map { NSStringFromClass(type(of: $0)) }
                .joined(separator: " -> ")
            print("ScreenshotKit nav[\(index)] \(NSStringFromClass(type(of: navigationController))) \(address) stack=[\(stackDescription)]")
        }

        print("ScreenshotKit navigation controller dump end")
    }

    private func dumpViewControllersIfNeeded() {
        guard !didDumpViewControllers else { return }
        didDumpViewControllers = true

        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)

        print("ScreenshotKit view controller dump begin")

        if windows.isEmpty {
            print("ScreenshotKit view controller dump: no windows found")
        }

        for (windowIndex, window) in windows.enumerated() {
            let address = String(describing: Unmanaged.passUnretained(window).toOpaque())
            print("ScreenshotKit window[\(windowIndex)] \(NSStringFromClass(type(of: window))) \(address)")

            guard let rootViewController = window.rootViewController else {
                print("ScreenshotKit window[\(windowIndex)] rootViewController=nil")
                continue
            }

            var visited = Set<ObjectIdentifier>()
            dumpViewControllerTree(
                rootViewController,
                indent: 0,
                visited: &visited
            )
        }

        print("ScreenshotKit view controller dump end")
    }

    private func allNavigationControllersInApplication() -> [UINavigationController] {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)

        var navigationControllers: [UINavigationController] = []
        var visited = Set<ObjectIdentifier>()

        for window in windows {
            guard let rootViewController = window.rootViewController else { continue }
            collectNavigationControllers(
                in: rootViewController,
                navigationControllers: &navigationControllers,
                visited: &visited
            )
        }

        return navigationControllers
    }

    private func firstNavigationController(in viewController: UIViewController) -> UINavigationController? {
        if let navigationController = viewController as? UINavigationController {
            return navigationController
        }

        for child in viewController.children {
            if let navigationController = firstNavigationController(in: child) {
                return navigationController
            }
        }

        if let presentedViewController = viewController.presentedViewController,
           let navigationController = firstNavigationController(in: presentedViewController) {
            return navigationController
        }

        return nil
    }

    private func collectNavigationControllers(
        in viewController: UIViewController,
        navigationControllers: inout [UINavigationController],
        visited: inout Set<ObjectIdentifier>
    ) {
        let identifier = ObjectIdentifier(viewController)
        guard visited.insert(identifier).inserted else { return }

        if let navigationController = viewController as? UINavigationController {
            navigationControllers.append(navigationController)
        }

        for child in viewController.children {
            collectNavigationControllers(
                in: child,
                navigationControllers: &navigationControllers,
                visited: &visited
            )
        }

        if let presentedViewController = viewController.presentedViewController {
            collectNavigationControllers(
                in: presentedViewController,
                navigationControllers: &navigationControllers,
                visited: &visited
            )
        }
    }

    private func dumpViewControllerTree(
        _ viewController: UIViewController,
        indent: Int,
        visited: inout Set<ObjectIdentifier>
    ) {
        let identifier = ObjectIdentifier(viewController)
        let prefix = String(repeating: "  ", count: indent)

        guard visited.insert(identifier).inserted else {
            print("\(prefix)- \(NSStringFromClass(type(of: viewController))) [visited]")
            return
        }

        let address = String(describing: Unmanaged.passUnretained(viewController).toOpaque())
        let parentDescription = viewController.parent.map {
            NSStringFromClass(type(of: $0))
        } ?? "nil"
        let navigationDescription = viewController.navigationController.map {
            NSStringFromClass(type(of: $0))
        } ?? "nil"
        let presentedDescription = viewController.presentedViewController.map {
            NSStringFromClass(type(of: $0))
        } ?? "nil"

        print(
            "\(prefix)- \(NSStringFromClass(type(of: viewController))) \(address) " +
            "parent=\(parentDescription) nav=\(navigationDescription) presented=\(presentedDescription) children=\(viewController.children.count)"
        )

        for child in viewController.children {
            dumpViewControllerTree(
                child,
                indent: indent + 1,
                visited: &visited
            )
        }

        if let presentedViewController = viewController.presentedViewController {
            dumpViewControllerTree(
                presentedViewController,
                indent: indent + 1,
                visited: &visited
            )
        }
    }

    private func dumpViewTree(
        _ view: UIView?,
        indent: Int,
        visited: inout Set<ObjectIdentifier>
    ) {
        guard let view else {
            let prefix = String(repeating: "  ", count: indent)
            print("\(prefix)- nil-view")
            return
        }

        let identifier = ObjectIdentifier(view)
        let prefix = String(repeating: "  ", count: indent)

        guard visited.insert(identifier).inserted else {
            print("\(prefix)- \(NSStringFromClass(type(of: view))) [visited]")
            return
        }

        let address = String(describing: Unmanaged.passUnretained(view).toOpaque())
        let frameDescription = NSCoder.string(for: view.frame)
        let boundsDescription = NSCoder.string(for: view.bounds)
        let transformDescription = NSCoder.string(for: view.transform)
        let backgroundDescription = view.backgroundColor.map {
            "\($0)"
        } ?? "nil"

        print(
            "\(prefix)- \(NSStringFromClass(type(of: view))) \(address) " +
            "frame=\(frameDescription) bounds=\(boundsDescription) " +
            "transform=\(transformDescription) " +
            "hidden=\(view.isHidden) alpha=\(view.alpha) " +
            "bg=\(backgroundDescription) subviews=\(view.subviews.count)"
        )

        for subview in view.subviews {
            dumpViewTree(
                subview,
                indent: indent + 1,
                visited: &visited
            )
        }
    }

    private func describeActivationState(_ activationState: UIScene.ActivationState) -> String {
        switch activationState {
        case .unattached:
            return "unattached"
        case .foregroundActive:
            return "foregroundActive"
        case .foregroundInactive:
            return "foregroundInactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
}

private struct ScreenshotNavigationContainer<Content: View>: View {
    let content: Content

    var body: some View {
        NavigationStack {
            content
        }
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

    func firstSubview(where predicate: (UIView) -> Bool) -> UIView? {
        if predicate(self) {
            return self
        }

        for subview in subviews {
            if let match = subview.firstSubview(where: predicate) {
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
        .navigationTitle("Hello")
        .toolbar{
            EditButton()
        }
    }
}
