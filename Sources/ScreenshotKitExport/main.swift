import Foundation

do {
    let options = try ExportOptions.parse(arguments: Array(CommandLine.arguments.dropFirst()))
    if options.showsHelp {
        FileHandle.standardError.write(Data((ExportOptions.helpText + "\n").utf8))
    } else {
        try await Exporter().run(options: options)
    }
} catch let error as ExportError {
    FileHandle.standardError.write(Data((error.message + "\n").utf8))
    exit(1)
} catch {
    FileHandle.standardError.write(Data((String(describing: error) + "\n").utf8))
    exit(1)
}
