import Foundation
import Testing
@testable import ScreenshotKit

@Test
func manifestCommandCreatesPlannedEntriesForAllLocalesAndScenes() async throws {
    let store = MockScreenshotProgressStore()
    let useCase = HandleScreenshotCommandUseCase(
        progressStore: store,
        localeProvider: MockScreenshotLocaleProvider(values: ["ja", "en"])
    )

    let progress = try await useCase.execute(
        command: .manifest(deviceName: "iPhone 16 Pro"),
        items: [
            ScreenshotDescriptor(id: "home", fallbackOutputIdentifier: "001"),
            ScreenshotDescriptor(id: "detail", fallbackOutputIdentifier: "002")
        ]
    )

    #expect(progress.mode == .manifest)
    #expect(progress.finished)
    #expect(progress.totalCount == 4)
    #expect(progress.completedCount == 4)
    #expect(progress.current == nil)
    #expect(progress.pending.isEmpty)
    #expect(progress.deviceName == "iPhone 16 Pro")
    #expect(progress.manifest?.entries.count == 4)
    #expect(progress.manifest?.entries[0].sceneID == "home")
    #expect(progress.manifest?.entries[0].localeIdentifier == "ja")
    #expect(progress.manifest?.entries[0].outputIdentifier == "001")
    #expect(progress.manifest?.entries[0].relativePath == nil)
    #expect(await store.createdDeviceNames == ["iPhone 16 Pro"])
}

@Test
func manifestCommandFinishesImmediatelyWhenThereAreNoJobs() async throws {
    let store = MockScreenshotProgressStore()
    let useCase = HandleScreenshotCommandUseCase(
        progressStore: store,
        localeProvider: MockScreenshotLocaleProvider(values: [])
    )

    let progress = try await useCase.execute(
        command: .manifest(deviceName: "iPhone SE"),
        items: []
    )

    #expect(progress.finished)
    #expect(progress.mode == .manifest)
    #expect(progress.current == nil)
    #expect(progress.pending.isEmpty)
    #expect(progress.totalCount == 0)
    #expect(progress.manifest?.entries.isEmpty == true)
    #expect(await store.finishedSessionURLs.isEmpty)
}

@Test
func captureCommandReturnsSingleRequestedScene() async throws {
    let store = MockScreenshotProgressStore()
    let useCase = HandleScreenshotCommandUseCase(
        progressStore: store,
        localeProvider: MockScreenshotLocaleProvider(values: ["ja"])
    )

    let progress = try await useCase.execute(
        command: .capture(
            deviceName: "iPhone 16 Pro",
            sceneID: "detail",
            localeIdentifier: "en-US",
            sessionDirectoryPath: "/tmp/session"
        ),
        items: [
            ScreenshotDescriptor(id: "home", fallbackOutputIdentifier: "001"),
            ScreenshotDescriptor(id: "detail", fallbackOutputIdentifier: "002")
        ]
    )

    #expect(progress.mode == .capture)
    #expect(progress.finished == false)
    #expect(progress.current?.sceneID == "detail")
    #expect(progress.current?.localeIdentifier == "en-US")
    #expect(progress.current?.fallbackOutputIdentifier == "002")
    #expect(progress.sessionDirectoryPath == "/tmp/session")
    #expect(progress.totalCount == 1)
    #expect(progress.manifest == nil)
}

@Test
func captureCommandRejectsUnknownScene() async throws {
    let store = MockScreenshotProgressStore()
    let useCase = HandleScreenshotCommandUseCase(
        progressStore: store,
        localeProvider: MockScreenshotLocaleProvider(values: ["ja"])
    )

    await #expect(throws: ScreenshotKitError.unknownSceneIdentifier("missing")) {
        try await useCase.execute(
            command: .capture(
                deviceName: "iPhone 16 Pro",
                sceneID: "missing",
                localeIdentifier: "en-US",
                sessionDirectoryPath: "/tmp/session"
            ),
            items: [
                ScreenshotDescriptor(id: "home", fallbackOutputIdentifier: "001")
            ]
        )
    }
}

@Test
func launchEnvironmentParserReadsManifestEnvironmentVariables() {
    let parser = ScreenshotLaunchEnvironmentParser()
    let processInfo = ProcessInfoFixture(
        arguments: [],
        environment: [
            ScreenshotLaunchEnvironmentParser.modeEnvironmentKey: ScreenshotLaunchEnvironmentParser.manifestModeValue,
            ScreenshotLaunchEnvironmentParser.deviceNameEnvironmentKey: "iPhone 17 Pro/Max"
        ]
    )

    let route = parser.parse(processInfo: processInfo)

    #expect(route?.command == .manifest(deviceName: "iPhone 17 Pro-Max"))
}

@Test
func launchEnvironmentParserReadsCaptureEnvironmentVariables() {
    let parser = ScreenshotLaunchEnvironmentParser()
    let processInfo = ProcessInfoFixture(
        arguments: [],
        environment: [
            ScreenshotLaunchEnvironmentParser.modeEnvironmentKey: ScreenshotLaunchEnvironmentParser.captureModeValue,
            ScreenshotLaunchEnvironmentParser.deviceNameEnvironmentKey: "iPhone 17 Pro/Max",
            ScreenshotLaunchEnvironmentParser.sceneIDEnvironmentKey: "detail",
            ScreenshotLaunchEnvironmentParser.localeEnvironmentKey: "en-US",
            ScreenshotLaunchEnvironmentParser.sessionDirectoryPathEnvironmentKey: "/tmp/session"
        ]
    )

    let route = parser.parse(processInfo: processInfo)

    #expect(
        route?.command == .capture(
            deviceName: "iPhone 17 Pro-Max",
            sceneID: "detail",
            localeIdentifier: "en-US",
            sessionDirectoryPath: "/tmp/session"
        )
    )
}

@Test
func launchEnvironmentParserSupportsManifestLaunchArguments() {
    let parser = ScreenshotLaunchEnvironmentParser()
    let processInfo = ProcessInfoFixture(
        arguments: [
            ScreenshotLaunchEnvironmentParser.modeArgument,
            ScreenshotLaunchEnvironmentParser.manifestModeValue,
            ScreenshotLaunchEnvironmentParser.deviceNameArgument,
            "iPad Pro 13-inch"
        ],
        environment: [:]
    )

    let route = parser.parse(processInfo: processInfo)

    #expect(route?.command == .manifest(deviceName: "iPad Pro 13-inch"))
}

@Test
func launchEnvironmentParserRejectsCaptureWithoutRequiredValues() {
    let parser = ScreenshotLaunchEnvironmentParser()
    let processInfo = ProcessInfoFixture(
        arguments: [
            ScreenshotLaunchEnvironmentParser.modeArgument,
            ScreenshotLaunchEnvironmentParser.captureModeValue,
            ScreenshotLaunchEnvironmentParser.deviceNameArgument,
            "iPhone 16"
        ],
        environment: [:]
    )

    let route = parser.parse(processInfo: processInfo)

    #expect(route == nil)
}

@Test
func localeProviderNormalizesCommonLanguageIdentifiers() {
    let provider = ScreenshotLocaleProvider(bundle: .moduleForTests(["ja", "en", "Base"]))

    #expect(provider.localeIdentifiers() == ["ja-JP", "en-US"])
}

@Test
func previewLayoutMetricsDetectPreviewEnvironment() {
    let processInfo = ProcessInfoFixture(
        arguments: [],
        environment: [ScreenshotPreviewLayoutMetrics.previewEnvironmentKey: "1"]
    )

    #expect(ScreenshotPreviewLayoutMetrics.isRunningForPreview(processInfo: processInfo))
}

@Test
func previewLayoutMetricsCompensateTopInsetOnlyInPreview() {
    #expect(
        ScreenshotPreviewLayoutMetrics.verticalCompensation(
            isRunningForPreview: true,
            deviceKind: .phone,
            topSafeAreaInset: 54
        ) == 54
    )
    #expect(
        ScreenshotPreviewLayoutMetrics.verticalCompensation(
            isRunningForPreview: false,
            deviceKind: .phone,
            topSafeAreaInset: 54
        ) == 0
    )
    #expect(
        ScreenshotPreviewLayoutMetrics.verticalCompensation(
            isRunningForPreview: true,
            deviceKind: .pad,
            topSafeAreaInset: 54
        ) == 0
    )
}

private actor MockScreenshotProgressStore: ScreenshotProgressStoreProtocol {
    var createdDeviceNames: [String] = []
    var finishedSessionURLs: [URL] = []
    var storedManifests: [ScreenshotManifest] = []
    var preparedCaptureSessionURLs: [URL] = []
    var captureReadyMessages: [(URL, String)] = []

    func createSession(deviceName: String) async throws -> URL {
        createdDeviceNames.append(deviceName)
        return URL(fileURLWithPath: "/tmp/mock-session", isDirectory: true)
    }

    func prepareForCapture(sessionDirectoryURL: URL) async throws {
        preparedCaptureSessionURLs.append(sessionDirectoryURL)
    }

    func markCaptureReady(sessionDirectoryURL: URL, message: String) async throws {
        captureReadyMessages.append((sessionDirectoryURL, message))
    }

    func markFinished(sessionDirectoryURL: URL, manifest: ScreenshotManifest) async throws {
        finishedSessionURLs.append(sessionDirectoryURL)
        storedManifests.append(manifest)
    }

    func markFailed(sessionDirectoryURL: URL, message: String) async throws {}
}

private struct MockScreenshotLocaleProvider: ScreenshotLocaleProviderProtocol {
    let values: [String]

    func localeIdentifiers() -> [String] {
        values
    }
}

private final class ProcessInfoFixture: ProcessInfo, @unchecked Sendable {
    private let fixtureArguments: [String]
    private let fixtureEnvironment: [String: String]

    init(arguments: [String], environment: [String: String]) {
        self.fixtureArguments = arguments
        self.fixtureEnvironment = environment
        super.init()
    }

    override var arguments: [String] {
        fixtureArguments
    }

    override var environment: [String: String] {
        fixtureEnvironment
    }
}

private extension Bundle {
    static func moduleForTests(_ localizations: [String]) -> Bundle {
        BundleLocalizationFixture(localizations: localizations)
    }
}

private final class BundleLocalizationFixture: Bundle, @unchecked Sendable {
    private let fixtureLocalizations: [String]

    init(localizations: [String]) {
        self.fixtureLocalizations = localizations
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var localizations: [String] {
        fixtureLocalizations
    }
}
