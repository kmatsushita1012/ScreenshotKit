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
    private var didDumpNavigationTitleCandidates = false
    private var isSchedulingDeferredTitleOffset = false

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        let verticalOffset: CGFloat = 44
        guard let navigationBar = targetNavigationBar() else {
            return
        }

        dumpNavigationTitleCandidatesIfNeeded(in: navigationBar)

        if !didConfigureNavigationBar {
            navigationBar.transform = CGAffineTransform(
                translationX: 0,
                y: verticalOffset
            )
            didConfigureNavigationBar = true
        }

        applyNavigationTitleOffsetIfNeeded(in: navigationBar)
        scheduleDeferredNavigationTitleOffsetIfNeeded(for: navigationBar)
    }

    private func targetNavigationBar() -> UIView? {
        if let localNavigationBar = hostingController.view.firstSubview(where: {
            NSStringFromClass(type(of: $0)).contains("UIKitNavigationBar")
        }) {
            return localNavigationBar
        }

        if let localNavigationBar = view.firstSubview(where: {
            NSStringFromClass(type(of: $0)).contains("UIKitNavigationBar")
        }) {
            return localNavigationBar
        }

        return nearestPresentationHostingController()?.view.firstSubview(where: {
            NSStringFromClass(type(of: $0)).contains("UIKitNavigationBar")
        })
    }

    private func applyNavigationTitleOffsetIfNeeded(in navigationBar: UIView) {
        let titleHorizontalOffset: CGFloat = 16
        for titleView in targetNavigationTitleViews(in: navigationBar) {
            applyHorizontalOffset(
                titleHorizontalOffset,
                to: titleView
            )
        }
    }

    private func scheduleDeferredNavigationTitleOffsetIfNeeded(for navigationBar: UIView) {
        guard !isSchedulingDeferredTitleOffset else { return }
        isSchedulingDeferredTitleOffset = true

        DispatchQueue.main.async { [weak self, weak navigationBar] in
            guard let self, let navigationBar else { return }
            self.isSchedulingDeferredTitleOffset = false
            self.applyNavigationTitleOffsetIfNeeded(in: navigationBar)
        }
    }

    private func applyHorizontalOffset(_ offset: CGFloat, to view: UIView) {
        if let label = view as? UILabel {
            var frame = label.frame
            if abs(frame.origin.x - offset) > 0.5 {
                frame.origin.x = offset
                label.frame = frame
            }
            return
        }

        let currentTransform = view.transform
        if abs(currentTransform.tx - offset) > 0.5 {
            view.transform = CGAffineTransform(
                translationX: offset,
                y: currentTransform.ty
            )
        }
    }

    private func targetNavigationTitleViews(in navigationBar: UIView) -> [UIView] {
        let searchRoots = [
            navigationBar,
            navigationBar.superview,
            nearestPresentationHostingController()?.view
        ].compactMap { $0 }

        let allSubviews = searchRoots
            .flatMap { $0.allSubviews() }

        let visibleLargeTitleLabels = allSubviews.compactMap { view -> UIView? in
            guard let label = view as? UILabel else { return nil }
            guard label.hasVisibleText else { return nil }
            guard label.isActuallyVisible else { return nil }
            guard label.nearestAncestor(where: {
                NSStringFromClass(type(of: $0)).contains("_UINavigationBarLargeTitleView")
            }) != nil else {
                return nil
            }
            return label
        }

        if !visibleLargeTitleLabels.isEmpty {
            return Array(NSOrderedSet(array: visibleLargeTitleLabels)) as? [UIView] ?? visibleLargeTitleLabels
        }

        let visibleInlineTitleLabels = allSubviews.compactMap { view -> UIView? in
            guard let label = view as? UILabel else { return nil }
            guard label.hasVisibleText else { return nil }
            guard label.isActuallyVisible else { return nil }
            guard label.nearestAncestor(where: {
                NSStringFromClass(type(of: $0)).contains("_UINavigationBarTitleControl")
            }) != nil else {
                return nil
            }
            return label
        }

        if !visibleInlineTitleLabels.isEmpty {
            return Array(NSOrderedSet(array: visibleInlineTitleLabels)) as? [UIView] ?? visibleInlineTitleLabels
        }

        let titleContainers = allSubviews.filter { view in
            let className = NSStringFromClass(type(of: view))
            return className.contains("_UINavigationBarLargeTitleView")
                || className.contains("_UINavigationBarTitleControl")
        }

        return Array(NSOrderedSet(array: titleContainers)) as? [UIView] ?? titleContainers
    }

    private func dumpNavigationTitleCandidatesIfNeeded(in navigationBar: UIView) {
        guard !didDumpNavigationTitleCandidates else { return }
        didDumpNavigationTitleCandidates = true

        let searchRoots = [
            ("navigationBar", navigationBar),
            ("navigationBar.superview", navigationBar.superview),
            ("presentationHost.view", nearestPresentationHostingController()?.view)
        ]

        logLine("ScreenshotKit navigation title candidate dump begin")

        for (name, root) in searchRoots {
            guard let root else {
                logLine("ScreenshotKit title-root \(name)=nil")
                continue
            }

            let address = String(describing: Unmanaged.passUnretained(root).toOpaque())
            logLine(
                "ScreenshotKit title-root \(name)=\(NSStringFromClass(type(of: root))) \(address) " +
                "frame=\(NSCoder.string(for: root.frame))"
            )
        }

        let candidates = targetNavigationTitleViews(in: navigationBar)
        if candidates.isEmpty {
            logLine("ScreenshotKit title-candidate none")
        }

        for (index, candidate) in candidates.enumerated() {
            logLine("ScreenshotKit title-candidate[\(index)] \(describeView(candidate))")

            var candidateVisited = Set<ObjectIdentifier>()
            logLine("ScreenshotKit title-candidate[\(index)] subtree begin")
            dumpViewTree(candidate, indent: 0, visited: &candidateVisited)
            logLine("ScreenshotKit title-candidate[\(index)] subtree end")
        }

        logLine("ScreenshotKit navigation title candidate subtree begin")
        var visited = Set<ObjectIdentifier>()
        dumpViewTree(navigationBar.superview ?? navigationBar, indent: 0, visited: &visited)
        logLine("ScreenshotKit navigation title candidate subtree end")
        logLine("ScreenshotKit navigation title candidate dump end")
    }

    private func dumpScenesIfNeeded() {
        guard !didDumpScenes else { return }
        didDumpScenes = true

        let connectedScenes = UIApplication.shared.connectedScenes
        logLine("ScreenshotKit scene dump begin")
        logLine("ScreenshotKit connectedScenes.count=\(connectedScenes.count)")

        if connectedScenes.isEmpty {
            logLine("ScreenshotKit scene dump: no connected scenes")
        }

        for (sceneIndex, scene) in connectedScenes.enumerated() {
            let sceneAddress = String(describing: Unmanaged.passUnretained(scene).toOpaque())
            let activationState = describeActivationState(scene.activationState)
            logLine(
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
                logLine(
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
        logLine(
            "ScreenshotKit self location vc=\(NSStringFromClass(type(of: self))) " +
            "window=\(ownWindowAddress) scene=\(ownSceneDescription) \(ownSceneAddress)"
        )
        logLine("ScreenshotKit scene dump end")
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

        logLine(
            "ScreenshotKit self appeared vc=\(NSStringFromClass(type(of: self))) \(ownAddress) " +
            "parent=\(parentDescription) nav=\(navigationDescription) " +
            "window=\(ownWindowAddress) scene=\(ownSceneDescription) \(ownSceneAddress)"
        )
    }

    private func dumpParentChainAfterAppearanceIfNeeded() {
        guard !didDumpParentChainAfterAppearance else { return }
        didDumpParentChainAfterAppearance = true

        logLine("ScreenshotKit parent chain dump begin")

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

            logLine(
                "ScreenshotKit parent[\(index)] \(NSStringFromClass(type(of: viewController))) \(address) " +
                "parent=\(parentDescription) nav=\(navigationDescription) " +
                "presented=\(presentedDescription) children=\(childrenCount)"
            )

            current = viewController.parent
            index += 1
        }

        logLine("ScreenshotKit parent chain dump end")
    }

    private func dumpPresentationViewHierarchyAfterAppearanceIfNeeded() {
        guard !didDumpPresentationViewHierarchyAfterAppearance else { return }
        didDumpPresentationViewHierarchyAfterAppearance = true

        guard let presentationParent = nearestPresentationHostingController() else {
            logLine("ScreenshotKit presentation view dump: parent presentation host not found")
            return
        }

        let address = String(describing: Unmanaged.passUnretained(presentationParent).toOpaque())
        logLine(
            "ScreenshotKit presentation view dump begin " +
            "\(NSStringFromClass(type(of: presentationParent))) \(address)"
        )

        var visited = Set<ObjectIdentifier>()
        dumpViewTree(
            presentationParent.view,
            indent: 0,
            visited: &visited
        )

        logLine("ScreenshotKit presentation view dump end")
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
        logLine("ScreenshotKit navigation controller dump begin")

        if navigationControllers.isEmpty {
            logLine("ScreenshotKit navigation controller dump: none found")
        }

        for (index, navigationController) in navigationControllers.enumerated() {
            let address = String(describing: Unmanaged.passUnretained(navigationController).toOpaque())
            let stackDescription = navigationController.viewControllers
                .map { NSStringFromClass(type(of: $0)) }
                .joined(separator: " -> ")
            logLine("ScreenshotKit nav[\(index)] \(NSStringFromClass(type(of: navigationController))) \(address) stack=[\(stackDescription)]")
        }

        logLine("ScreenshotKit navigation controller dump end")
    }

    private func dumpViewControllersIfNeeded() {
        guard !didDumpViewControllers else { return }
        didDumpViewControllers = true

        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)

        logLine("ScreenshotKit view controller dump begin")

        if windows.isEmpty {
            logLine("ScreenshotKit view controller dump: no windows found")
        }

        for (windowIndex, window) in windows.enumerated() {
            let address = String(describing: Unmanaged.passUnretained(window).toOpaque())
            logLine("ScreenshotKit window[\(windowIndex)] \(NSStringFromClass(type(of: window))) \(address)")

            guard let rootViewController = window.rootViewController else {
                logLine("ScreenshotKit window[\(windowIndex)] rootViewController=nil")
                continue
            }

            var visited = Set<ObjectIdentifier>()
            dumpViewControllerTree(
                rootViewController,
                indent: 0,
                visited: &visited
            )
        }

        logLine("ScreenshotKit view controller dump end")
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
            logLine("ScreenshotKit vc-tree \(prefix)- \(NSStringFromClass(type(of: viewController))) [visited]")
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

        logLine(
            "ScreenshotKit vc-tree \(prefix)- \(NSStringFromClass(type(of: viewController))) \(address) " +
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
            logLine("ScreenshotKit view-tree \(prefix)- nil-view")
            return
        }

        let identifier = ObjectIdentifier(view)
        let prefix = String(repeating: "  ", count: indent)

        guard visited.insert(identifier).inserted else {
            logLine("ScreenshotKit view-tree \(prefix)- \(NSStringFromClass(type(of: view))) [visited]")
            return
        }

        let address = String(describing: Unmanaged.passUnretained(view).toOpaque())
        let frameDescription = NSCoder.string(for: view.frame)
        let boundsDescription = NSCoder.string(for: view.bounds)
        let transformDescription = NSCoder.string(for: view.transform)
        let backgroundDescription = view.backgroundColor.map {
            "\($0)"
        } ?? "nil"
        let extraDescription = viewDebugSummary(view)

        logLine(
            "ScreenshotKit view-tree \(prefix)- \(NSStringFromClass(type(of: view))) \(address) " +
            "frame=\(frameDescription) bounds=\(boundsDescription) " +
            "transform=\(transformDescription) " +
            "hidden=\(view.isHidden) alpha=\(view.alpha) " +
            "bg=\(backgroundDescription) subviews=\(view.subviews.count)\(extraDescription)"
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

    private func describeView(_ view: UIView) -> String {
        let address = String(describing: Unmanaged.passUnretained(view).toOpaque())
        let frameDescription = NSCoder.string(for: view.frame)
        let transformDescription = NSCoder.string(for: view.transform)
        let extraDescription = viewDebugSummary(view)
        return
            "\(NSStringFromClass(type(of: view))) \(address) " +
            "frame=\(frameDescription) transform=\(transformDescription)\(extraDescription)"
    }

    private func viewDebugSummary(_ view: UIView) -> String {
        var parts: [String] = []

        if let label = view as? UILabel {
            parts.append(" text=\"\(label.text ?? "")\"")
        }

        if let button = view as? UIButton {
            parts.append(" title=\"\(button.title(for: .normal) ?? "")\"")
        }

        if let imageView = view as? UIImageView, let image = imageView.image {
            parts.append(" image=\(image)")
        }

        if let accessibilityIdentifier = view.accessibilityIdentifier {
            parts.append(" a11yId=\(accessibilityIdentifier)")
        }

        if let accessibilityLabel = view.accessibilityLabel {
            parts.append(" a11yLabel=\"\(accessibilityLabel)\"")
        }

        return parts.isEmpty ? "" : parts.joined(separator: "")
    }

    private func logLine(_ message: String) {
        NSLog("%@", message)
    }
}

private struct ScreenshotNavigationContainer<Content: View>: View {
    let content: Content

    var body: some View {
        NavigationStack {
            ScreenshotContentOffsetContainer {
                content
            }
        }
    }
}

private struct ScreenshotContentOffsetContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .safeAreaInset(edge: .top) {
                Color.clear
                    .frame(height: 44)
            }
    }
}

private extension UIView {
    var isActuallyVisible: Bool {
        guard !isHidden, alpha > 0.01 else { return false }
        return superview?.isActuallyVisible ?? true
    }

    func nearestAncestor(where predicate: (UIView) -> Bool) -> UIView? {
        var current = superview
        while let view = current {
            if predicate(view) {
                return view
            }
            current = view.superview
        }
        return nil
    }

    func allSubviews() -> [UIView] {
        [self] + subviews.flatMap { $0.allSubviews() }
    }

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

private extension UILabel {
    var hasVisibleText: Bool {
        guard let text else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
