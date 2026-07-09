import Foundation

struct SimulatorService {
    let runner: CommandRunner

    func chooseSimulators() throws -> SimulatorPlan {
        let runtimes = try runner.runJSON(
            ["xcrun", "simctl", "list", "--json", "runtimes", "available"],
            as: RuntimeList.self
        )
        let devices = try runner.runJSON(
            ["xcrun", "simctl", "list", "--json", "devices", "available"],
            as: DeviceList.self
        )
        let deviceTypes = try runner.runJSON(
            ["xcrun", "simctl", "list", "--json", "devicetypes"],
            as: DeviceTypeList.self
        )

        let availableRuntimes = runtimes.runtimes.filter {
            $0.isAvailable && $0.platform == "iOS"
        }
        guard let runtime = availableRuntimes.max(by: { lhs, rhs in
            numericVersionKey(lhs.versionKey).lexicographicallyPrecedes(
                numericVersionKey(rhs.versionKey)
            )
        }) else {
            throw ExportError("No available iOS runtimes")
        }

        let devicesForRuntime = devices.devices[runtime.identifier, default: []].filter(\.isAvailable)
        guard !devicesForRuntime.isEmpty else {
            throw ExportError("No available devices found for runtime \(runtime.identifier)")
        }

        let typeLookup = Dictionary(uniqueKeysWithValues: deviceTypes.devicetypes.map { ($0.name, $0.identifier) })
        let iphone = try pickDevice(kind: "iPhone", from: devicesForRuntime, typeLookup: typeLookup, scorer: iphoneScore)
        let ipad = try pickDevice(kind: "iPad", from: devicesForRuntime, typeLookup: typeLookup, scorer: ipadScore)

        return SimulatorPlan(runtimeID: runtime.identifier, iphone: iphone, ipad: ipad)
    }

    func deviceInfo(for udid: String) throws -> DeviceInfo {
        let devices = try runner.runJSON(
            ["xcrun", "simctl", "list", "devices", "--json"],
            as: DeviceList.self
        )

        for (runtimeID, runtimeDevices) in devices.devices {
            if let device = runtimeDevices.first(where: { $0.udid == udid }) {
                return DeviceInfo(runtimeID: runtimeID, name: device.name, isAvailable: device.isAvailable)
            }
        }
        throw ExportError("Device not found: \(udid)")
    }

    func ensureDevice(runtimeID: String, descriptor: DeviceDescriptor) throws -> String {
        if !descriptor.udid.isEmpty {
            return descriptor.udid
        }
        return try runner.run(
            ["xcrun", "simctl", "create", "ScreenshotKit \(descriptor.name)", descriptor.typeIdentifier, runtimeID]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func bootDevice(_ udid: String) throws {
        _ = try? runner.run(["xcrun", "simctl", "boot", udid])
        _ = try runner.run(["xcrun", "simctl", "bootstatus", udid, "-b"])
    }

    func installApp(udid: String, bundleID: String, appPath: String) throws {
        _ = try? runner.run(["xcrun", "simctl", "uninstall", udid, bundleID])
        _ = try runner.run(["xcrun", "simctl", "install", udid, appPath])
    }

    func terminateApp(udid: String, bundleID: String) {
        _ = try? runner.run(["xcrun", "simctl", "terminate", udid, bundleID])
    }

    func appContainerPath(udid: String, bundleID: String) throws -> String {
        try runner.run(
            ["xcrun", "simctl", "get_app_container", udid, bundleID, "data"]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func launchApp(
        udid: String,
        bundleID: String,
        environment: [String: String],
        arguments: [String] = []
    ) throws {
        var command = ["xcrun", "simctl", "launch", "--terminate-running-process", udid, bundleID]
        command.append(contentsOf: arguments)
        _ = try runner.run(command, environment: environment)
    }

    func captureScreenshot(udid: String, outputPath: String) throws {
        _ = try runner.run(["xcrun", "simctl", "io", udid, "screenshot", "--mask", "ignored", outputPath])
    }

    func warmUpCapture(udid: String) async throws {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("screenshotkit-warmup-\(UUID().uuidString).png")
        try await Utilities.sleep(seconds: 2)
        try captureScreenshot(udid: udid, outputPath: temporaryURL.path)
        try? FileManager.default.removeItem(at: temporaryURL)
    }

    private func pickDevice(
        kind: String,
        from devices: [SimDevice],
        typeLookup: [String: String],
        scorer: (String) -> [Int]?
    ) throws -> DeviceDescriptor {
        let candidates = devices.compactMap { device -> (score: [Int], device: SimDevice)? in
            guard let score = scorer(device.name) else { return nil }
            return (score, device)
        }

        guard let selected = candidates.max(by: { $0.score.lexicographicallyPrecedes($1.score) })?.device else {
            throw ExportError("No available \(kind) device found")
        }

        let typeIdentifier = selected.deviceTypeIdentifier ?? typeLookup[selected.name]
        guard let typeIdentifier else {
            throw ExportError("Device type identifier missing for \(selected.name)")
        }

        return DeviceDescriptor(name: selected.name, typeIdentifier: typeIdentifier, udid: selected.udid)
    }

    private func numericVersionKey(_ value: String) -> [Int] {
        value
            .replacingOccurrences(of: "-", with: ".")
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }

    private func iphoneScore(_ name: String) -> [Int]? {
        guard name.hasPrefix("iPhone ") else { return nil }
        let generation = Int(name.split(separator: " ").dropFirst().first ?? "0") ?? 0
        let tier: Int
        if name.contains("Pro Max") {
            tier = 4
        } else if name.contains("Pro") {
            tier = 3
        } else if name.contains("Plus") {
            tier = 2
        } else if name.contains(" e") || name.hasSuffix("e") {
            tier = 0
        } else {
            tier = 1
        }
        return [tier, generation]
    }

    private func ipadScore(_ name: String) -> [Int]? {
        guard name.hasPrefix("iPad") else { return nil }
        let family: Int
        if name.contains("iPad Pro") {
            family = 4
        } else if name.contains("iPad Air") {
            family = 3
        } else if name == "iPad" || name.hasPrefix("iPad (") {
            family = 2
        } else if name.contains("iPad mini") {
            family = 1
        } else {
            family = 0
        }

        let chip = chipGeneration(in: name)
        let size = name.contains("13-inch") || name.contains("12.9-inch") ? 3 : (name.contains("11-inch") ? 2 : 0)
        let memory = name.contains("16GB") ? 1 : 0
        return [family, chip, size, memory]
    }

    private func chipGeneration(in name: String) -> Int {
        guard let range = name.range(of: "(M") else { return 0 }
        let suffix = name[range.upperBound...]
        let digits = suffix.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }
}

private struct RuntimeList: Decodable {
    let runtimes: [Runtime]
}

private struct Runtime: Decodable {
    let identifier: String
    let isAvailable: Bool
    let platform: String
    let version: String?

    var versionKey: String {
        version ?? identifier.components(separatedBy: "iOS-").last ?? "0"
    }
}

private struct DeviceList: Decodable {
    let devices: [String: [SimDevice]]
}

private struct SimDevice: Decodable {
    let name: String
    let udid: String
    let isAvailable: Bool
    let deviceTypeIdentifier: String?
}

private struct DeviceTypeList: Decodable {
    let devicetypes: [SimDeviceType]
}

private struct SimDeviceType: Decodable {
    let name: String
    let identifier: String
}
