import Foundation

struct Exporter {
    private let runner = CommandRunner()
    private let fileManager = FileManager.default

    func run(options: ExportOptions) async throws {
        let workingDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        let outputRoot = Utilities.outputRootURL(from: options.outputRoot, relativeTo: workingDirectory)
        try fileManager.createDirectory(at: outputRoot, withIntermediateDirectories: true)

        let projectInspector = ProjectInspector(
            runner: runner,
            fileManager: fileManager,
            workingDirectory: workingDirectory
        )
        let simulatorService = SimulatorService(runner: runner)
        let project = try projectInspector.inferProjectSettings(projectOverride: options.projectPathOverride)
        let derivedDataPath = workingDirectory.appendingPathComponent(".build/example-derived-data").path
        let appPath = "\(derivedDataPath)/Build/Products/Debug-iphonesimulator/\(project.fullProductName)"

        if let deviceID = options.deviceIDOverride {
            let deviceInfo = try simulatorService.deviceInfo(for: deviceID)
            guard deviceInfo.isAvailable else {
                throw ExportError("Device is not available: \(deviceID)")
            }
            try simulatorService.bootDevice(deviceID)
            try buildApp(project: project, derivedDataPath: derivedDataPath)
            try simulatorService.installApp(udid: deviceID, bundleID: project.bundleID, appPath: appPath)
            try await runCaptureForDevice(
                project: project,
                udid: deviceID,
                rawDeviceName: deviceInfo.name,
                outputRoot: outputRoot,
                simulatorService: simulatorService
            )
            return
        }

        let plan = try simulatorService.chooseSimulators()
        let iphoneUDID = try simulatorService.ensureDevice(runtimeID: plan.runtimeID, descriptor: plan.iphone)
        let ipadUDID = try simulatorService.ensureDevice(runtimeID: plan.runtimeID, descriptor: plan.ipad)

        try simulatorService.bootDevice(iphoneUDID)
        try simulatorService.bootDevice(ipadUDID)
        try buildApp(project: project, derivedDataPath: derivedDataPath)
        try simulatorService.installApp(udid: iphoneUDID, bundleID: project.bundleID, appPath: appPath)
        try simulatorService.installApp(udid: ipadUDID, bundleID: project.bundleID, appPath: appPath)

        try await runCaptureForDevice(
            project: project,
            udid: iphoneUDID,
            rawDeviceName: plan.iphone.name,
            outputRoot: outputRoot,
            simulatorService: simulatorService
        )
        try await runCaptureForDevice(
            project: project,
            udid: ipadUDID,
            rawDeviceName: plan.ipad.name,
            outputRoot: outputRoot,
            simulatorService: simulatorService
        )
    }

    private func buildApp(project: ProjectSettings, derivedDataPath: String) throws {
        try runner.runStreaming([
            "xcodebuild",
            "build",
            "-project", project.projectPath,
            "-scheme", project.scheme,
            "-configuration", "Debug",
            "-destination", "generic/platform=iOS Simulator",
            "-derivedDataPath", derivedDataPath,
            "CODE_SIGNING_ALLOWED=NO",
        ])
    }

    private func runCaptureForDevice(
        project: ProjectSettings,
        udid: String,
        rawDeviceName: String,
        outputRoot: URL,
        simulatorService: SimulatorService
    ) async throws {
        let manifestInfo = try await waitForManifest(
            bundleID: project.bundleID,
            udid: udid,
            rawDeviceName: rawDeviceName,
            outputRoot: outputRoot,
            simulatorService: simulatorService
        )

        let manifestURL = URL(fileURLWithPath: manifestInfo.manifestPath)
        let outputManifestURL = URL(fileURLWithPath: manifestInfo.outputManifestPath)
        let manifest = try JSONDecoder().decode(
            ScreenshotManifest.self,
            from: Data(contentsOf: manifestURL)
        )

        for entry in manifest.entries {
            let resolvedOutputIdentifier = try await captureScene(
                project: project,
                udid: udid,
                rawDeviceName: rawDeviceName,
                sessionDirectoryPath: manifestInfo.sessionDirectoryPath,
                outputRoot: outputRoot,
                entry: entry,
                simulatorService: simulatorService
            )
            try updateManifestEntry(
                manifestURL: outputManifestURL,
                deviceName: manifest.deviceName,
                sceneID: entry.sceneID,
                localeIdentifier: entry.localeIdentifier,
                outputIdentifier: resolvedOutputIdentifier
            )
        }
    }

    private func waitForManifest(
        bundleID: String,
        udid: String,
        rawDeviceName: String,
        outputRoot: URL,
        simulatorService: SimulatorService
    ) async throws -> ManifestInfo {
        let deviceName = Utilities.sanitizePathComponent(rawDeviceName)
        let outputManifestURL = outputRoot.appendingPathComponent("\(deviceName)-manifest.json")
        let appContainer = try simulatorService.appContainerPath(udid: udid, bundleID: bundleID)
        let sessionsDirectory = URL(fileURLWithPath: appContainer)
            .appendingPathComponent("Library/Application Support/ScreenshotKit/Sessions")
        let latestSessionPointerURL = sessionsDirectory.appendingPathComponent("latest-session.txt")

        simulatorService.terminateApp(udid: udid, bundleID: bundleID)
        try simulatorService.launchApp(
            udid: udid,
            bundleID: bundleID,
            environment: [
                "SIMCTL_CHILD_SCREENSHOTKIT_MODE": "manifest",
                "SIMCTL_CHILD_SCREENSHOTKIT_DEVICE_NAME": rawDeviceName,
            ]
        )
        try await simulatorService.warmUpCapture(udid: udid)

        for _ in 0..<300 {
            if fileManager.fileExists(atPath: latestSessionPointerURL.path) {
                let sessionPath = try String(contentsOf: latestSessionPointerURL)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !sessionPath.isEmpty {
                    let sessionURL = URL(fileURLWithPath: sessionPath, isDirectory: true)
                    let manifestURL = sessionURL.appendingPathComponent("manifest.json")
                    let completeURL = sessionURL.appendingPathComponent("capture-complete")
                    let errorURL = sessionURL.appendingPathComponent("capture-error.txt")

                    if fileManager.fileExists(atPath: errorURL.path) {
                        throw ExportError(try String(contentsOf: errorURL))
                    }

                    if fileManager.fileExists(atPath: manifestURL.path),
                       fileManager.fileExists(atPath: completeURL.path) {
                        try fileManager.copyItem(at: manifestURL, to: outputManifestURL, replacingIfNeeded: true)
                        return ManifestInfo(
                            sessionDirectoryPath: sessionURL.path,
                            manifestPath: manifestURL.path,
                            outputManifestPath: outputManifestURL.path
                        )
                    }
                }
            }
            try await Utilities.sleep(seconds: 1)
        }

        throw ExportError("timed out waiting for manifest on \(rawDeviceName)")
    }

    private func captureScene(
        project: ProjectSettings,
        udid: String,
        rawDeviceName: String,
        sessionDirectoryPath: String,
        outputRoot: URL,
        entry: ScreenshotManifestEntry,
        simulatorService: SimulatorService
    ) async throws -> String {
        let deviceName = Utilities.sanitizePathComponent(rawDeviceName)
        let localeDirectory = outputRoot
            .appendingPathComponent(deviceName)
            .appendingPathComponent(entry.localeIdentifier)
        try fileManager.createDirectory(at: localeDirectory, withIntermediateDirectories: true)

        let actualOutputIdentifier = try await waitForCaptureReadiness(
            project: project,
            udid: udid,
            rawDeviceName: rawDeviceName,
            sceneID: entry.sceneID,
            localeIdentifier: entry.localeIdentifier,
            sessionDirectoryPath: sessionDirectoryPath,
            simulatorService: simulatorService
        )
        let resolvedOutputIdentifier = actualOutputIdentifier ?? entry.outputIdentifier
        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent("screenshotkit-shot-\(UUID().uuidString).png")
        let targetURL = localeDirectory.appendingPathComponent("\(resolvedOutputIdentifier).png")

        try await Utilities.sleep(seconds: 1)
        try simulatorService.captureScreenshot(udid: udid, outputPath: tempURL.path)
        try fileManager.moveItem(at: tempURL, to: targetURL, replacingIfNeeded: true)
        simulatorService.terminateApp(udid: udid, bundleID: project.bundleID)
        return resolvedOutputIdentifier
    }

    private func waitForCaptureReadiness(
        project: ProjectSettings,
        udid: String,
        rawDeviceName: String,
        sceneID: String,
        localeIdentifier: String,
        sessionDirectoryPath: String,
        simulatorService: SimulatorService
    ) async throws -> String? {
        let sessionURL = URL(fileURLWithPath: sessionDirectoryPath, isDirectory: true)
        let markerURL = sessionURL.appendingPathComponent("capture-complete")
        let errorURL = sessionURL.appendingPathComponent("capture-error.txt")
        let localeValues = Utilities.parseAppleLocaleValues(localeIdentifier: localeIdentifier)

        simulatorService.terminateApp(udid: udid, bundleID: project.bundleID)
        try simulatorService.launchApp(
            udid: udid,
            bundleID: project.bundleID,
            environment: [
                "SIMCTL_CHILD_SCREENSHOTKIT_MODE": "capture",
                "SIMCTL_CHILD_SCREENSHOTKIT_DEVICE_NAME": rawDeviceName,
                "SIMCTL_CHILD_SCREENSHOTKIT_SCENE_ID": sceneID,
                "SIMCTL_CHILD_SCREENSHOTKIT_LOCALE": localeIdentifier,
                "SIMCTL_CHILD_SCREENSHOTKIT_SESSION_PATH": sessionDirectoryPath,
            ],
            arguments: [
                "-AppleLanguages", localeValues.languages,
                "-AppleLocale", localeValues.locale,
            ]
        )

        let expectedPrefix = "SCREENSHOTKIT_READY sceneID=\(sceneID) locale=\(localeIdentifier) "
        for _ in 0..<15 {
            if fileManager.fileExists(atPath: errorURL.path) {
                throw ExportError(try String(contentsOf: errorURL))
            }
            if fileManager.fileExists(atPath: markerURL.path) {
                let marker = try String(contentsOf: markerURL)
                if marker.contains(expectedPrefix) {
                    return marker.components(separatedBy: "outputIdentifier=").last?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            try await Utilities.sleep(seconds: 1)
        }

        try await Utilities.sleep(seconds: 1)

        if fileManager.fileExists(atPath: errorURL.path) {
            throw ExportError(try String(contentsOf: errorURL))
        }
        return nil
    }

    private func updateManifestEntry(
        manifestURL: URL,
        deviceName: String,
        sceneID: String,
        localeIdentifier: String,
        outputIdentifier: String
    ) throws {
        let data = try Data(contentsOf: manifestURL)
        var manifest = try JSONDecoder().decode(ScreenshotManifest.self, from: data)
        for index in manifest.entries.indices {
            guard manifest.entries[index].sceneID == sceneID,
                  manifest.entries[index].localeIdentifier == localeIdentifier else {
                continue
            }
            manifest.entries[index].outputIdentifier = outputIdentifier
            manifest.entries[index].relativePath = "\(deviceName)/\(localeIdentifier)/\(outputIdentifier).png"
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }
}

private extension FileManager {
    func copyItem(at sourceURL: URL, to destinationURL: URL, replacingIfNeeded: Bool) throws {
        if replacingIfNeeded, fileExists(atPath: destinationURL.path) {
            try removeItem(at: destinationURL)
        }
        try copyItem(at: sourceURL, to: destinationURL)
    }

    func moveItem(at sourceURL: URL, to destinationURL: URL, replacingIfNeeded: Bool) throws {
        if replacingIfNeeded, fileExists(atPath: destinationURL.path) {
            try removeItem(at: destinationURL)
        }
        try moveItem(at: sourceURL, to: destinationURL)
    }
}
