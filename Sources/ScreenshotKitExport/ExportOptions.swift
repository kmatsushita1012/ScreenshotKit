import Foundation

struct ExportOptions: Sendable, Equatable {
    let outputRoot: String
    let deviceIDOverride: String?
    let projectPathOverride: String?
    let showsHelp: Bool

    static func parse(arguments: [String]) throws -> ExportOptions {
        var outputRoot = "./output"
        var deviceIDOverride: String?
        var projectPathOverride: String?
        var positional: [String] = []

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--output-dir":
                index += 1
                outputRoot = try value(for: argument, at: index, in: arguments)
            case "--device-id":
                index += 1
                deviceIDOverride = try value(for: argument, at: index, in: arguments)
            case "--project", "--xcodeproj":
                index += 1
                projectPathOverride = try value(for: argument, at: index, in: arguments)
            case "--help", "-h":
                return ExportOptions(
                    outputRoot: outputRoot,
                    deviceIDOverride: deviceIDOverride,
                    projectPathOverride: projectPathOverride,
                    showsHelp: true
                )
            default:
                if argument.hasPrefix("--") {
                    throw ExportError("unknown option: \(argument)")
                }
                positional.append(argument)
            }
            index += 1
        }

        guard positional.count <= 2 else {
            throw ExportError(helpText)
        }
        if positional.indices.contains(0) {
            outputRoot = positional[0]
        }
        if positional.indices.contains(1) {
            deviceIDOverride = positional[1]
        }

        return ExportOptions(
            outputRoot: outputRoot,
            deviceIDOverride: deviceIDOverride,
            projectPathOverride: projectPathOverride,
            showsHelp: false
        )
    }

    static let helpText = """
    usage: screenshotkit-export [output-dir] [device-id] [--project path/to/App.xcodeproj]
           screenshotkit-export [--output-dir dir] [--device-id udid] [--project path/to/App.xcodeproj]
    """

    private static func value(
        for option: String,
        at index: Int,
        in arguments: [String]
    ) throws -> String {
        guard arguments.indices.contains(index) else {
            throw ExportError("missing value for \(option)")
        }
        return arguments[index]
    }
}

struct ExportError: LocalizedError, Sendable, Equatable {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
