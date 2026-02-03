import ArgumentParser
import AsyncClosureLinterCore
import Foundation

@main
struct AsyncClosureLinterCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "async-closure-lint",
        abstract: "Lint Swift files to ensure async closure properties in SwiftUI Views have @MainActor"
    )

    @Argument(help: "Swift files or directories to lint")
    var paths: [String]

    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose = false

    mutating func run() throws {
        let linter = AsyncClosureLinter()
        var hasViolations = false

        for path in paths {
            let violations = try lintPath(path, linter: linter)
            for violation in violations {
                print(violation)
                hasViolations = true
            }
        }

        if hasViolations {
            throw ExitCode.failure
        }
    }

    func lintPath(_ path: String, linter: AsyncClosureLinter) throws -> [Violation] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw ValidationError("Path does not exist: \(path)")
        }

        if isDirectory.boolValue {
            return try linter.lintDirectory(at: path)
        } else {
            return try linter.lintFile(at: path)
        }
    }
}
