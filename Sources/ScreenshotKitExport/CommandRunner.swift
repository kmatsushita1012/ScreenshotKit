import Foundation

struct CommandRunner: Sendable {
    func run(_ command: [String], environment: [String: String] = [:]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command

        var mergedEnvironment = ProcessInfo.processInfo.environment
        mergedEnvironment.merge(environment) { _, new in new }
        process.environment = mergedEnvironment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        guard process.terminationStatus == 0 else {
            let detail = stderr.isEmpty ? stdout : stderr
            throw ExportError(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return stdout
    }

    func runJSON<T: Decodable>(_ command: [String], as type: T.Type) throws -> T {
        let output = try run(command)
        let data = Data(output.utf8)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func runStreaming(_ command: [String], environment: [String: String] = [:]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command

        var mergedEnvironment = ProcessInfo.processInfo.environment
        mergedEnvironment.merge(environment) { _, new in new }
        process.environment = mergedEnvironment
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ExportError("command failed: \(command.joined(separator: " "))")
        }
    }
}
