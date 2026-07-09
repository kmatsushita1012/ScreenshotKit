import Foundation

struct ProjectInspector {
    let runner: CommandRunner
    let fileManager: FileManager
    let workingDirectory: URL

    func inferProjectSettings(projectOverride: String?) throws -> ProjectSettings {
        if let projectOverride {
            let projectPath = Utilities.resolvePath(projectOverride, relativeTo: workingDirectory)
            guard projectPath.hasSuffix(".xcodeproj"), fileManager.fileExists(atPath: projectPath) else {
                throw ExportError("Specified project not found or not an .xcodeproj: \(projectOverride)")
            }
            return try projectSettings(for: projectPath)
        }

        let projects = discoverProjects()
        guard !projects.isEmpty else {
            throw ExportError("No .xcodeproj found under current directory")
        }

        let candidates = try projects.map { path in
            (settings: try projectSettings(for: path), score: score(for: path))
        }

        return candidates.max { lhs, rhs in
            lhs.score.lexicographicallyPrecedes(rhs.score)
        }?.settings ?? {
            fatalError("unreachable")
        }()
    }

    private func discoverProjects() -> [String] {
        let enumerator = fileManager.enumerator(
            at: workingDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var results: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "xcodeproj" else { continue }
            results.append(url.standardizedFileURL.path)
        }
        return results.sorted()
    }

    private func projectSettings(for projectPath: String) throws -> ProjectSettings {
        let scheme = try schemeName(for: projectPath)
        let entries = try buildSettingsEntries(projectPath: projectPath, scheme: scheme)

        let target = entries.first(where: \.isApplicationTarget) ?? entries.first
        guard let target else {
            throw ExportError("Could not infer usable app settings from project: \(projectPath)")
        }

        guard let bundleID = target.buildSettings.productBundleIdentifier, !bundleID.isEmpty else {
            throw ExportError("Could not infer usable app settings from project: \(projectPath)")
        }

        return ProjectSettings(
            projectPath: projectPath,
            scheme: scheme,
            bundleID: bundleID,
            fullProductName: target.buildSettings.fullProductName ?? "\(scheme).app",
            executableName: target.buildSettings.executableName ?? scheme
        )
    }

    private func schemeName(for projectPath: String) throws -> String {
        let payload = try runner.runJSON(
            ["xcodebuild", "-list", "-json", "-project", projectPath],
            as: XcodeListPayload.self
        )
        let schemes = payload.project?.schemes ?? []
        if let preferred = schemes.first(where: { !$0.hasSuffix("Tests") && !$0.hasSuffix("UITests") }) {
            return preferred
        }
        guard let first = schemes.first else {
            throw ExportError("No usable scheme found in project: \(projectPath)")
        }
        return first
    }

    private func buildSettingsEntries(projectPath: String, scheme: String) throws -> [BuildSettingsEntry] {
        try runner.runJSON(
            ["xcodebuild", "-showBuildSettings", "-json", "-project", projectPath, "-scheme", scheme],
            as: [BuildSettingsEntry].self
        )
    }

    private func score(for projectPath: String) -> [Int] {
        let relative = URL(fileURLWithPath: projectPath).path.replacingOccurrences(of: workingDirectory.path + "/", with: "")
        let parts = relative.split(separator: "/")
        let projectName = URL(fileURLWithPath: projectPath).deletingPathExtension().lastPathComponent
        let parentName = URL(fileURLWithPath: projectPath).deletingLastPathComponent().lastPathComponent

        return [
            parts.count == 2 ? 1 : 0,
            parentName == projectName ? 1 : 0,
            -parts.count
        ]
    }
}

private struct XcodeListPayload: Decodable {
    let project: XcodeProject?
}

private struct XcodeProject: Decodable {
    let schemes: [String]
}

private struct BuildSettingsEntry: Decodable {
    let buildSettings: BuildSettings

    var isApplicationTarget: Bool {
        buildSettings.productType == "com.apple.product-type.application"
            || buildSettings.wrapperExtension == "app"
    }
}

private struct BuildSettings: Decodable {
    let productType: String?
    let wrapperExtension: String?
    let productBundleIdentifier: String?
    let fullProductName: String?
    let executableName: String?

    enum CodingKeys: String, CodingKey {
        case productType = "PRODUCT_TYPE"
        case wrapperExtension = "WRAPPER_EXTENSION"
        case productBundleIdentifier = "PRODUCT_BUNDLE_IDENTIFIER"
        case fullProductName = "FULL_PRODUCT_NAME"
        case executableName = "EXECUTABLE_NAME"
    }
}
