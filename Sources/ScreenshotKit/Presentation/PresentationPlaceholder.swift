//
//  PresentationPlaceholder.swift
//  ScreenshotKit
//

import Combine
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
    private let handleUseCase: any HandleScreenshotCommandUseCaseProtocol
    private let progressStore: any ScreenshotProgressStoreProtocol

    private var pendingJobs: [ScreenshotCaptureJob] = []
    private var isCaptureRunning = false
    private var activeCaptureKey: String?
    private var currentDeviceName = "unknown-device"
    private var currentCaptureSource: DisplayedSceneCaptureSource?
    private var manifestEntries: [ScreenshotManifestEntry] = []

    init(
        urlScheme: String,
        registry: ScreenshotRegistry,
        urlParser: any ScreenshotURLParserProtocol,
        handleUseCase: any HandleScreenshotCommandUseCaseProtocol,
        progressStore: any ScreenshotProgressStoreProtocol
    ) {
        self.urlScheme = urlScheme
        self.registry = registry
        self.urlParser = urlParser
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
            handleUseCase: HandleScreenshotCommandUseCase(
                progressStore: progressStore,
                localeProvider: ScreenshotLocaleProvider()
            ),
            progressStore: progressStore
        )
    }

    func handleOpenURL(_ url: URL) {
        guard let route = urlParser.parse(url, expectedScheme: urlScheme) else { return }
        process(command: route.command)
    }

    func sceneDidBecomeCapturable(_ source: DisplayedSceneCaptureSource) {
        guard source.taskID == currentJob?.id else { return }
        currentCaptureSource = source

        Task {
            await performCaptureIfNeeded()
        }
    }

    private func process(command: ScreenshotCommand) {
        Task {
            do {
                let progress = try await handleUseCase.execute(
                    command: command,
                    items: registry.descriptors
                )

                await MainActor.run {
                    applyProgress(progress)
                }
            } catch {
                await MainActor.run {
                    applyError(error)
                }
            }
        }
    }

    private func applyProgress(_ progress: ScreenshotProgress) {
        isScreenshotMode = true
        isFinished = progress.finished
        currentJob = progress.current
        pendingJobs = progress.pending
        sessionDirectoryPath = progress.sessionDirectoryPath
        completedCount = progress.completedCount
        totalCount = progress.totalCount
        currentDeviceName = progress.deviceName
        currentCaptureSource = nil
        manifestEntries = []
        isCaptureRunning = false
        activeCaptureKey = nil
    }

    private func applyError(_ error: Error) {
        lastErrorMessage = String(describing: error)
        isScreenshotMode = true
        isFinished = true
        currentJob = nil
        pendingJobs = []
        currentCaptureSource = nil
    }

    private func performCaptureIfNeeded() async {
        guard let currentJob else { return }
        guard !isFinished else { return }
        guard let sessionDirectoryPath else { return }
        guard let currentCaptureSource else { return }
        guard currentCaptureSource.taskID == currentJob.id else { return }

        let captureKey = currentJob.id
        guard activeCaptureKey != captureKey || !isCaptureRunning else { return }

        activeCaptureKey = captureKey
        isCaptureRunning = true

        do {
            guard let captureView = currentCaptureSource.viewBox.view else {
                throw ScreenshotKitError.captureFailed
            }

            let outputIdentifier = sanitizedOutputIdentifier(
                currentCaptureSource.outputIdentifier
            ) ?? currentJob.fallbackOutputIdentifier

            let pngData = try renderPNGData(from: captureView)
            let sessionDirectoryURL = URL(fileURLWithPath: sessionDirectoryPath, isDirectory: true)

            let entry = try await progressStore.saveImage(
                pngData,
                sessionDirectoryURL: sessionDirectoryURL,
                deviceName: currentDeviceName,
                localeIdentifier: sanitizedPathComponent(currentJob.localeIdentifier),
                outputIdentifier: outputIdentifier,
                sceneID: currentJob.sceneID
            )

            manifestEntries.append(entry)
            completedCount += 1
            advanceToNextJob(from: sessionDirectoryURL)
        } catch {
            applyCaptureError(error)
        }
    }

    private func advanceToNextJob(from sessionDirectoryURL: URL) {
        if pendingJobs.isEmpty {
            currentJob = nil
            isFinished = true
            currentCaptureSource = nil
            isCaptureRunning = false
            activeCaptureKey = nil

            let manifest = ScreenshotManifest(
                deviceName: currentDeviceName,
                sessionDirectoryPath: sessionDirectoryURL.path,
                entries: manifestEntries,
                completedAt: Date()
            )

            Task {
                try? await progressStore.markFinished(
                    sessionDirectoryURL: sessionDirectoryURL,
                    manifest: manifest
                )
            }
            return
        }

        currentJob = pendingJobs.removeFirst()
        currentCaptureSource = nil
        isCaptureRunning = false
        activeCaptureKey = nil
    }

    private func applyCaptureError(_ error: Error) {
        let message = String(describing: error)
        lastErrorMessage = message
        isFinished = true
        currentJob = nil
        pendingJobs = []
        currentCaptureSource = nil
        isCaptureRunning = false
        activeCaptureKey = nil

        guard let sessionDirectoryPath else { return }
        let sessionDirectoryURL = URL(fileURLWithPath: sessionDirectoryPath, isDirectory: true)

        Task {
            try? await progressStore.markFailed(sessionDirectoryURL: sessionDirectoryURL, message: message)
        }
    }

    private func renderPNGData(from view: UIView) throws -> Data {
        let bounds = view.bounds.integral
        guard !bounds.isEmpty else {
            throw ScreenshotKitError.captureFailed
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = view.window?.screen.scale ?? UIScreen.main.scale
        format.opaque = false

        let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
            if !view.drawHierarchy(in: bounds, afterScreenUpdates: true) {
                view.layer.render(in: UIGraphicsGetCurrentContext()!)
            }
        }

        guard let data = image.pngData() else {
            throw ScreenshotKitError.captureFailed
        }

        return data
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
                    onCaptureSourceReady: { source in
                        viewModel.sceneDidBecomeCapturable(source)
                    }
                )
            }
        }
        .onOpenURL { url in
            viewModel.handleOpenURL(url)
        }
    }
}

struct ScreenshotHostView: View {
    let registry: ScreenshotRegistry
    let currentJob: ScreenshotCaptureJob?
    let isFinished: Bool
    let onCaptureSourceReady: (DisplayedSceneCaptureSource) -> Void

    var body: some View {
        if isFinished {
            ScreenshotFinishedView()
        } else if let currentJob, let view = registry.makeView(currentJob.sceneID) {
            LiveRenderedScreenshotScene(
                taskID: currentJob.id,
                localeIdentifier: currentJob.localeIdentifier,
                content: view,
                onCaptureSourceReady: onCaptureSourceReady
            )
        } else {
            Text("No current screenshot item")
                .padding()
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
struct DisplayedSceneCaptureSource {
    let taskID: String
    let outputIdentifier: String?
    let viewBox: WeakUIViewBox
}

@MainActor
final class WeakUIViewBox {
    weak var view: UIView?

    init(view: UIView?) {
        self.view = view
    }
}

private struct LiveRenderedScreenshotScene: UIViewControllerRepresentable {
    let taskID: String
    let localeIdentifier: String
    let content: AnyView
    let onCaptureSourceReady: (DisplayedSceneCaptureSource) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCaptureSourceReady: onCaptureSourceReady)
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
            content: AnyView(
                content.environment(\.locale, Locale(identifier: localeIdentifier))
            ),
            onOutputIdentifierResolved: { outputIdentifier in
                coordinator.outputIdentifierDidResolve(outputIdentifier)
            }
        )
    }

    @MainActor
    final class Coordinator {
        private let onCaptureSourceReady: (DisplayedSceneCaptureSource) -> Void
        private var taskID = ""
        private var outputIdentifier: String?
        private var didResolveOutputIdentifier = false
        private var didPublish = false
        private var viewBox = WeakUIViewBox(view: nil)

        init(onCaptureSourceReady: @escaping (DisplayedSceneCaptureSource) -> Void) {
            self.onCaptureSourceReady = onCaptureSourceReady
        }

        func prepareForUpdate(taskID: String) {
            if self.taskID == taskID {
                return
            }

            self.taskID = taskID
            outputIdentifier = nil
            didResolveOutputIdentifier = false
            didPublish = false
            viewBox = WeakUIViewBox(view: nil)
        }

        func outputIdentifierDidResolve(_ outputIdentifier: String?) {
            self.outputIdentifier = outputIdentifier
            didResolveOutputIdentifier = true
            publishIfReady()
        }

        func captureViewDidLayout(_ view: UIView) {
            viewBox = WeakUIViewBox(view: view)
            publishIfReady()
        }

        private func publishIfReady() {
            guard !didPublish else { return }
            guard didResolveOutputIdentifier else { return }
            guard viewBox.view != nil else { return }

            didPublish = true
            onCaptureSourceReady(
                DisplayedSceneCaptureSource(
                    taskID: taskID,
                    outputIdentifier: outputIdentifier,
                    viewBox: viewBox
                )
            )
        }
    }
}

private final class CaptureHostingViewController: UIHostingController<CaptureMetadataReportingRoot> {
    var onLayout: ((UIView) -> Void)?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onLayout?(view)
    }
}

private struct CaptureMetadataReportingRoot: View {
    let content: AnyView
    let onOutputIdentifierResolved: (String?) -> Void

    @State private var hasResolvedOutputIdentifier = false

    var body: some View {
        content
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
