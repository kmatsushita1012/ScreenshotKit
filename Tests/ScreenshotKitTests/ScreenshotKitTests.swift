import Foundation
import Testing
@testable import ScreenshotKit

@Test
func startCommandCreatesBatchJobsForAllLocalesAndScenes() async throws {
    let store = MockScreenshotProgressStore()
    let useCase = HandleScreenshotCommandUseCase(
        progressStore: store,
        localeProvider: MockScreenshotLocaleProvider(values: ["ja", "en"])
    )

    let progress = try await useCase.execute(
        command: .start(deviceName: "iPhone 16 Pro"),
        items: [
            ScreenshotDescriptor(id: "home", fallbackOutputIdentifier: "001"),
            ScreenshotDescriptor(id: "detail", fallbackOutputIdentifier: "002")
        ]
    )

    #expect(progress.finished == false)
    #expect(progress.totalCount == 4)
    #expect(progress.completedCount == 0)
    #expect(progress.current?.sceneID == "home")
    #expect(progress.current?.localeIdentifier == "ja")
    #expect(progress.pending.count == 3)
    #expect(progress.pending[0].sceneID == "detail")
    #expect(progress.pending[1].localeIdentifier == "en")
    #expect(progress.deviceName == "iPhone 16 Pro")
    #expect(await store.createdDeviceNames == ["iPhone 16 Pro"])
}

@Test
func startCommandFinishesImmediatelyWhenThereAreNoJobs() async throws {
    let store = MockScreenshotProgressStore()
    let useCase = HandleScreenshotCommandUseCase(
        progressStore: store,
        localeProvider: MockScreenshotLocaleProvider(values: [])
    )

    let progress = try await useCase.execute(
        command: .start(deviceName: "iPhone SE"),
        items: []
    )

    #expect(progress.finished)
    #expect(progress.current == nil)
    #expect(progress.pending.isEmpty)
    #expect(progress.totalCount == 0)
    #expect(await store.finishedSessionURLs.count == 1)
}

@Test
func urlParserReadsAndSanitizesDeviceName() {
    let parser = ScreenshotURLParser()
    let url = URL(string: "myapp://screenshot/start?deviceName=iPhone%2016%20Pro/Max")!

    let route = parser.parse(url, expectedScheme: "myapp")

    #expect(route?.command == .start(deviceName: "iPhone 16 Pro-Max"))
}

@Test
func urlParserAlsoAcceptsScreenshotsPathStyle() {
    let parser = ScreenshotURLParser()
    let url = URL(string: "myapp:/screenshots/start?deviceName=iPad%20Pro")!

    let route = parser.parse(url, expectedScheme: "myapp")

    #expect(route?.command == .start(deviceName: "iPad Pro"))
}

@Test
func urlParserAlsoAcceptsScreenshotsHostStyle() {
    let parser = ScreenshotURLParser()
    let url = URL(string: "myapp://screenshots/start?deviceName=iPhone%2017%20Pro")!

    let route = parser.parse(url, expectedScheme: "myapp")

    #expect(route?.command == .start(deviceName: "iPhone 17 Pro"))
}

@Test
func urlParserMatchesSchemeCaseInsensitively() {
    let parser = ScreenshotURLParser()
    let url = URL(string: "MyApp://screenshots/start?deviceName=iPad")!

    let route = parser.parse(url, expectedScheme: "myapp")

    #expect(route?.command == .start(deviceName: "iPad"))
}

@Test
func launchEnvironmentParserReadsEnvironmentVariables() {
    let parser = ScreenshotLaunchEnvironmentParser()
    let processInfo = ProcessInfoFixture(
        arguments: [],
        environment: [
            ScreenshotLaunchEnvironmentParser.autoStartEnvironmentKey: "1",
            ScreenshotLaunchEnvironmentParser.deviceNameEnvironmentKey: "iPhone 17 Pro/Max"
        ]
    )

    let route = parser.parse(processInfo: processInfo)

    #expect(route?.command == .start(deviceName: "iPhone 17 Pro-Max"))
}

@Test
func launchEnvironmentParserSupportsLaunchArguments() {
    let parser = ScreenshotLaunchEnvironmentParser()
    let processInfo = ProcessInfoFixture(
        arguments: [
            ScreenshotLaunchEnvironmentParser.autoStartArgument,
            ScreenshotLaunchEnvironmentParser.deviceNameArgument,
            "iPad Pro 13-inch"
        ],
        environment: [:]
    )

    let route = parser.parse(processInfo: processInfo)

    #expect(route?.command == .start(deviceName: "iPad Pro 13-inch"))
}

@Test
func launchEnvironmentParserIgnoresMissingAutostartSignal() {
    let parser = ScreenshotLaunchEnvironmentParser()
    let processInfo = ProcessInfoFixture(
        arguments: [ScreenshotLaunchEnvironmentParser.deviceNameArgument, "iPhone 16"],
        environment: [ScreenshotLaunchEnvironmentParser.deviceNameEnvironmentKey: "iPhone 16"]
    )

    let route = parser.parse(processInfo: processInfo)

    #expect(route == nil)
}

@Test
func localeProviderNormalizesCommonLanguageIdentifiers() {
    let provider = ScreenshotLocaleProvider(bundle: .moduleForTests(["ja", "en", "Base"]))

    #expect(provider.localeIdentifiers() == ["ja-JP", "en-US"])
}

private actor MockScreenshotProgressStore: ScreenshotProgressStoreProtocol {
    var createdDeviceNames: [String] = []
    var finishedSessionURLs: [URL] = []
    var storedManifests: [ScreenshotManifest] = []

    func createSession(deviceName: String) async throws -> URL {
        createdDeviceNames.append(deviceName)
        return URL(fileURLWithPath: "/tmp/mock-session", isDirectory: true)
    }

    func saveImage(
        _ data: Data,
        sessionDirectoryURL: URL,
        deviceName: String,
        localeIdentifier: String,
        outputIdentifier: String,
        sceneID: String
    ) async throws -> ScreenshotManifestEntry {
        ScreenshotManifestEntry(
            sceneID: sceneID,
            localeIdentifier: localeIdentifier,
            outputIdentifier: outputIdentifier,
            relativePath: "\(deviceName)/\(localeIdentifier)/\(outputIdentifier).png"
        )
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
