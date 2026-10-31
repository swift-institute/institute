import Foundation
import PackagePlugin

/// Fails the build of a SwiftPM target on a finding of the rules in `Lint.Rule.Bundle.buildErrors`.
///
/// The check runs as a build command, because SwiftPM refuses a prebuild command that runs an executable built from
/// source. Its output is a stamp file that the tool writes only when no error was found, and that is a Swift file, so
/// the target's compilation depends on the check: a finding stops the build before the compiler starts, in seconds,
/// where the compiler it guards against can take half an hour to give up. It prints `path:line:column: error: message`
/// lines, which Xcode and SwiftPM show as build errors.
@main
struct BuildErrors: BuildToolPlugin {

    /// The executable target the plugin depends on.
    static let tool = "Institute Linter Build Errors"

    func createBuildCommands(context: PluginContext, target: any Target) async throws -> [Command] {
        guard let module = target.sourceModule else { return [] }
        return try Self.commands(
            named: module.name,
            tool: context.tool(named: Self.tool).url,
            root: context.package.directoryURL,
            files: module.sourceFiles(withSuffix: ".swift").map(\.url),
            work: context.pluginWorkDirectoryURL
        )
    }

    static func commands(named name: String, tool: URL, root: URL, files: [URL], work: URL) -> [Command] {
        guard !files.isEmpty else { return [] }
        let stamp = work.appending(path: "LinterBuildErrors.swift")
        return [
            .buildCommand(
                displayName: "Linter build errors: \(name)",
                executable: tool,
                arguments: ["--root", root.path(percentEncoded: false), "--stamp", stamp.path(percentEncoded: false)]
                    + files.map { $0.path(percentEncoded: false) },
                inputFiles: files,
                outputFiles: [stamp]
            )
        ]
    }
}
