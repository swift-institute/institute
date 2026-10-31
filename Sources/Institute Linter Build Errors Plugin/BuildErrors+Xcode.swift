#if canImport(XcodeProjectPlugin)
    import Foundation
    import PackagePlugin
    import XcodeProjectPlugin

    /// The same check for a target of an Xcode project, added through Build Phases, Run Build Tool Plug-ins.
    extension BuildErrors: XcodeBuildToolPlugin {

        func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
            try Self.commands(
                named: target.displayName,
                tool: context.tool(named: Self.tool).url,
                root: context.xcodeProject.directoryURL,
                files: target.inputFiles.map(\.url).filter { $0.pathExtension == "swift" },
                work: context.pluginWorkDirectoryURL
            )
        }
    }
#endif
