//
//  PresentationPlaceholder.swift
//  ScreenshotKit
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public protocol ScreenshotItem: View, Sendable {
    static var id: String { get }
}

@resultBuilder
public enum ScreenshotItemsBuilder {
    public static func buildBlock(_ components: any ScreenshotItem...) -> [any ScreenshotItem] {
        components
    }
}

struct ScreenshotRegistry: @unchecked Sendable {
    let descriptors: [ScreenshotDescriptor]
    let makeView: @Sendable (_ id: String) -> AnyView?
}

@MainActor
private func makeRegistry(from items: [any ScreenshotItem]) -> ScreenshotRegistry {
    var descriptors: [ScreenshotDescriptor] = []
    var mutableFactories: [String: @Sendable () -> AnyView] = [:]

    for (index, item) in items.enumerated() {
        let metatype = type(of: item)
        let id = metatype.id
        let fallbackOutputIdentifier = String(format: "%03d", index + 1)

        descriptors.append(
            ScreenshotDescriptor(
                id: id,
                fallbackOutputIdentifier: fallbackOutputIdentifier
            )
        )
        mutableFactories[id] = { AnyView(item) }
    }

    let factories = mutableFactories
    let factory: @Sendable (_ id: String) -> AnyView? = { id in
        factories[id]?()
    }

    return ScreenshotRegistry(descriptors: descriptors, makeView: factory)
}

public extension View {
    func screenshot(
        urlScheme: String,
        @ScreenshotItemsBuilder items: () -> [any ScreenshotItem]
    ) -> some View {
        modifier(
            ScreenshotModifier(
                urlScheme: urlScheme,
                items: items()
            )
        )
    }
}

private struct ScreenshotModifier: ViewModifier {
    let urlScheme: String
    let items: [any ScreenshotItem]

    func body(content: Content) -> some View {
#if canImport(UIKit)
        let registry = makeRegistry(from: items)

        do {
            try ValidateScreenshotItemsUseCase().execute(items: registry.descriptors)
        } catch {
            // Validation failure is surfaced when the capture flow starts.
        }

        return ScreenshotContainerView(
            content: content,
            urlScheme: urlScheme,
            registry: registry
        )
#else
        content
#endif
    }
}

#if canImport(UIKit)
@MainActor
final class ScreenshotContainerViewModel: ObservableObject {
    static let readinessLogPrefix = "SCREENSHOTKIT_READY"

    @Published private(set) var isScreenshotMode = false
    @Published private(set) var currentJob: ScreenshotCaptureJob?
    @Published private(set) var isFinished = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var sessionDirectoryPath: String?
    @Published private(set) var completedCount = 0
    @Published private(set) var totalCount = 0

    private let urlScheme: String
    private let registry: ScreenshotRegistry
    private let urlParser: any ScreenshotURLParserProtocol
    private let launchEnvironmentParser: any ScreenshotLaunchEnvironmentParserProtocol
    private let handleUseCase: any HandleScreenshotCommandUseCaseProtocol
    private let progressStore: any ScreenshotProgressStoreProtocol

    private var hasProcessedLaunchEnvironment = false
    private var activeReadinessKey: String?

    init(
        urlScheme: String,
        registry: ScreenshotRegistry,
        urlParser: any ScreenshotURLParserProtocol,
        launchEnvironmentParser: any ScreenshotLaunchEnvironmentParserProtocol,
        handleUseCase: any HandleScreenshotCommandUseCaseProtocol,
        progressStore: any ScreenshotProgressStoreProtocol
    ) {
        self.urlScheme = urlScheme
        self.registry = registry
        self.urlParser = urlParser
        self.launchEnvironmentParser = launchEnvironmentParser
        self.handleUseCase = handleUseCase
        self.progressStore = progressStore
    }

    convenience init(urlScheme: String, registry: ScreenshotRegistry) {
        let progressStore = ScreenshotProgressStore(
            fileClient: FileClient(),
            stateFileLocator: ScreenshotStateFileLocator()
        )

        self.init(
            urlScheme: urlScheme,
            registry: registry,
            urlParser: ScreenshotURLParser(),
            launchEnvironmentParser: ScreenshotLaunchEnvironmentParser(),
            handleUseCase: HandleScreenshotCommandUseCase(
                progressStore: progressStore,
                localeProvider: ScreenshotLocaleProvider()
            ),
            progressStore: progressStore
        )
    }

    func handleOpenURL(_ url: URL) {
        print("ScreenshotKit received URL: \(url.absoluteString)")
        guard let route = urlParser.parse(url, expectedScheme: urlScheme) else { return }
        process(command: route.command)
    }

    func handleLaunchEnvironmentIfNeeded(processInfo: ProcessInfo = .processInfo) {
        guard !hasProcessedLaunchEnvironment else { return }
        hasProcessedLaunchEnvironment = true

        guard let route = launchEnvironmentParser.parse(processInfo: processInfo) else {
            return
        }

        print("ScreenshotKit autostart detected from ProcessInfo")
        process(command: route.command)
    }

    func sceneDidBecomeReady(_ readiness: ScreenshotSceneReadiness) {
        guard readiness.taskID == currentJob?.id else { return }

        Task {
            await publishReadinessIfNeeded(readiness)
        }
    }

    private func process(command: ScreenshotCommand) {
        Task {
            do {
                let progress = try await handleUseCase.execute(
                    command: command,
                    items: registry.descriptors
                )

                try await prepareProgressArtifacts(progress)

                await MainActor.run {
                    applyProgress(progress)
                }
            } catch {
                await MainActor.run {
                    applyError(error, command: command)
                }
            }
        }
    }

    private func prepareProgressArtifacts(_ progress: ScreenshotProgress) async throws {
        guard let sessionDirectoryPath = progress.sessionDirectoryPath else {
            if progress.mode == .capture {
                throw ScreenshotKitError.missingSessionDirectoryPath
            }
            return
        }

        let sessionDirectoryURL = URL(fileURLWithPath: sessionDirectoryPath, isDirectory: true)

        switch progress.mode {
        case .manifest:
            if let manifest = progress.manifest {
                try await progressStore.markFinished(
                    sessionDirectoryURL: sessionDirectoryURL,
                    manifest: manifest
                )
            }
        case .capture:
            try await progressStore.prepareForCapture(sessionDirectoryURL: sessionDirectoryURL)
        }
    }

    private func applyProgress(_ progress: ScreenshotProgress) {
        isScreenshotMode = true
        isFinished = progress.finished
        currentJob = progress.current
        sessionDirectoryPath = progress.sessionDirectoryPath
        completedCount = progress.completedCount
        totalCount = progress.totalCount
        activeReadinessKey = nil
    }

    private func applyError(_ error: Error, command: ScreenshotCommand) {
        lastErrorMessage = String(describing: error)
        isScreenshotMode = true
        isFinished = true
        currentJob = nil
        activeReadinessKey = nil

        guard let sessionDirectoryPath = sessionDirectoryPath(for: command) else { return }
        let sessionDirectoryURL = URL(fileURLWithPath: sessionDirectoryPath, isDirectory: true)
        let message = String(describing: error)

        Task {
            try? await progressStore.markFailed(sessionDirectoryURL: sessionDirectoryURL, message: message)
        }
    }

    private func publishReadinessIfNeeded(_ readiness: ScreenshotSceneReadiness) async {
        guard let currentJob else { return }
        guard let sessionDirectoryPath else { return }
        guard currentJob.id == readiness.taskID else { return }

        let readinessKey = readiness.taskID
        guard activeReadinessKey != readinessKey else { return }
        activeReadinessKey = readinessKey

        let outputIdentifier = sanitizedOutputIdentifier(
            readiness.outputIdentifier
        ) ?? currentJob.fallbackOutputIdentifier
        let message = "\(Self.readinessLogPrefix) sceneID=\(currentJob.sceneID) locale=\(currentJob.localeIdentifier) outputIdentifier=\(outputIdentifier)"
        let sessionDirectoryURL = URL(fileURLWithPath: sessionDirectoryPath, isDirectory: true)

        do {
            try await progressStore.markCaptureReady(
                sessionDirectoryURL: sessionDirectoryURL,
                message: message
            )
            print(message)
        } catch {
            applyError(error, command: .capture(
                deviceName: "unknown-device",
                sceneID: currentJob.sceneID,
                localeIdentifier: currentJob.localeIdentifier,
                sessionDirectoryPath: sessionDirectoryPath
            ))
        }
    }

    private func sessionDirectoryPath(for command: ScreenshotCommand) -> String? {
        switch command {
        case .manifest:
            return nil
        case let .capture(_, _, _, sessionDirectoryPath):
            return sessionDirectoryPath
        }
    }

    private func sanitizedOutputIdentifier(_ outputIdentifier: String?) -> String? {
        guard let outputIdentifier else { return nil }

        let sanitized = sanitizedPathComponent(outputIdentifier)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized.isEmpty ? nil : sanitized
    }

    private func sanitizedPathComponent(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let scalars = value.unicodeScalars.map { invalidCharacters.contains($0) ? "-" : Character($0) }
        return String(scalars)
    }
}

public struct ScreenshotContainerView<Content: View>: View {
    let content: Content
    let urlScheme: String
    let registry: ScreenshotRegistry

    @StateObject private var viewModel: ScreenshotContainerViewModel

    init(
        content: Content,
        urlScheme: String,
        registry: ScreenshotRegistry
    ) {
        self.content = content
        self.urlScheme = urlScheme
        self.registry = registry
        _viewModel = StateObject(
            wrappedValue: ScreenshotContainerViewModel(
                urlScheme: urlScheme,
                registry: registry
            )
        )
    }

    public var body: some View {
        Group {
            if !viewModel.isScreenshotMode {
                content
            } else if viewModel.isFinished {
                ScreenshotFinishedView()
            } else {
                ScreenshotHostView(
                    registry: registry,
                    currentJob: viewModel.currentJob,
                    isFinished: viewModel.isFinished,
                    onSceneReady: { readiness in
                        viewModel.sceneDidBecomeReady(readiness)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
        }
        .onOpenURL { url in
            viewModel.handleOpenURL(url)
        }
        .task {
            viewModel.handleLaunchEnvironmentIfNeeded()
        }
    }
}

struct ScreenshotHostView: View {
    let registry: ScreenshotRegistry
    let currentJob: ScreenshotCaptureJob?
    let isFinished: Bool
    let onSceneReady: (ScreenshotSceneReadiness) -> Void

    var body: some View {
        if isFinished {
            ScreenshotFinishedView()
        } else if let currentJob, let view = registry.makeView(currentJob.sceneID) {
            LiveRenderedScreenshotScene(
                taskID: currentJob.id,
                localeIdentifier: currentJob.localeIdentifier,
                content: view,
                onSceneReady: onSceneReady
            )
            .id(currentJob.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        } else {
            Text("No current screenshot item")
                .padding()
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
struct ScreenshotSceneReadiness {
    let taskID: String
    let outputIdentifier: String?
}

private struct LiveRenderedScreenshotScene: UIViewControllerRepresentable {
    let taskID: String
    let localeIdentifier: String
    let content: AnyView
    let onSceneReady: (ScreenshotSceneReadiness) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSceneReady: onSceneReady)
    }

    func makeUIViewController(context: Context) -> CaptureHostingViewController {
        let controller = CaptureHostingViewController(rootView: makeRootView(for: context.coordinator))
        controller.view.backgroundColor = .clear
        controller.onLayout = { [weak coordinator = context.coordinator] view in
            coordinator?.captureViewDidLayout(view)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: CaptureHostingViewController, context: Context) {
        context.coordinator.prepareForUpdate(taskID: taskID)
        uiViewController.rootView = makeRootView(for: context.coordinator)
        uiViewController.onLayout = { [weak coordinator = context.coordinator] view in
            coordinator?.captureViewDidLayout(view)
        }
    }

    private func makeRootView(for coordinator: Coordinator) -> CaptureMetadataReportingRoot {
        CaptureMetadataReportingRoot(
            taskID: taskID,
            content: AnyView(
                content.environment(\.locale, Locale(identifier: localeIdentifier))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .statusBarHidden(true)
                    .ignoresSafeArea()
            ),
            onOutputIdentifierResolved: { outputIdentifier in
                coordinator.outputIdentifierDidResolve(outputIdentifier)
            }
        )
    }

    @MainActor
    final class Coordinator {
        private let onSceneReady: (ScreenshotSceneReadiness) -> Void
        private var taskID = ""
        private var outputIdentifier: String?
        private var didResolveOutputIdentifier = false
        private var didPublish = false
        private var hasLaidOutView = false

        init(onSceneReady: @escaping (ScreenshotSceneReadiness) -> Void) {
            self.onSceneReady = onSceneReady
        }

        func prepareForUpdate(taskID: String) {
            if self.taskID == taskID {
                return
            }

            self.taskID = taskID
            outputIdentifier = nil
            didResolveOutputIdentifier = false
            didPublish = false
            hasLaidOutView = false
        }

        func outputIdentifierDidResolve(_ outputIdentifier: String?) {
            self.outputIdentifier = outputIdentifier
            didResolveOutputIdentifier = true
            publishIfReady()
        }

        func captureViewDidLayout(_ view: UIView) {
            hasLaidOutView = true
            publishIfReady()
        }

        private func publishIfReady() {
            guard !didPublish else { return }
            guard didResolveOutputIdentifier else { return }
            guard hasLaidOutView else { return }

            didPublish = true
            onSceneReady(
                ScreenshotSceneReadiness(
                    taskID: taskID,
                    outputIdentifier: outputIdentifier
                )
            )
        }
    }
}

private final class CaptureHostingViewController: UIHostingController<CaptureMetadataReportingRoot> {
    var onLayout: ((UIView) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.insetsLayoutMarginsFromSafeArea = false

        if #available(iOS 16.4, *) {
            safeAreaRegions = []
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onLayout?(view)
    }
}

private struct CaptureMetadataReportingRoot: View {
    let taskID: String
    let content: AnyView
    let onOutputIdentifierResolved: (String?) -> Void

    @State private var hasResolvedOutputIdentifier = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onPreferenceChange(ScreenshotOutputIdentifierPreferenceKey.self) { value in
                guard !hasResolvedOutputIdentifier else { return }
                hasResolvedOutputIdentifier = true
                onOutputIdentifierResolved(value)
            }
            .task {
                guard !hasResolvedOutputIdentifier else { return }
                try? await Task.sleep(for: .milliseconds(50))
                guard !hasResolvedOutputIdentifier else { return }
                hasResolvedOutputIdentifier = true
                onOutputIdentifierResolved(nil)
            }
    }
}

public struct ScreenshotFinishedView: View {
    public init() {}

    public var body: some View {
        Color.clear.accessibilityHidden(true)
    }
}
#else
public struct ScreenshotFinishedView: View {
    public init() {}

    public var body: some View {
        Color.clear.accessibilityHidden(true)
    }
}
#endif
