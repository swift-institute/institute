public import Command
public import Command_Schema
import Environment
import File_System
public import Institute_Instruments
public import Institute_Model
import Process

/// File-scope alias: inside `Institute.Coherence`, the bare name
/// `Environment` resolves to the domain's receipt environment, not the
/// process-environment module this command reads from.
private typealias ProcessEnvironment = Environment

extension Institute.Coherence {
    /// `institute coherence` — measure selection coherence.
    public struct Command: Sendable, Command_Schema.Command.`Protocol` {
        public var buildPath: Institute.Coherence.BuildPath?

        public init(buildPath: Institute.Coherence.BuildPath? = nil) {
            self.buildPath = buildPath
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "coherence", abstract: "Measure the whole selection's coherence.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.buildPath,
                    name: .long(.literal("build-path")),
                    placeholder: "xcodebuild-merged|swiftpm-composed-root",
                    help: .init(
                        abstract:
                            "Which build path measures coherence (defaults to xcodebuild-merged, "
                            + "issue #80); swiftpm-composed-root is the Ubuntu-capable Phase 2 "
                            + "path (issue #81)."
                    )
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            guard let working = ProcessEnvironment.read("PWD") else {
                throw .configuration("PWD is not available")
            }
            let checkout: File.Directory
            do throws(File.Path.Error) {
                checkout = try File.Directory(validating: working)
            } catch {
                throw .configuration("Institute checkout is not a valid path: \(error)")
            }
            let root = try Institute.Root(checkout: checkout)
            let configuration = try Institute.Configuration.load(at: root.checkout)
            let selection = try Institute.Selection.effective(at: root.checkout, in: configuration)
            print(selection.origin)
            let receipt = await Institute.Coherence.Run(
                root: root,
                configuration: configuration,
                selection: selection,
                buildPath: buildPath ?? .xcodebuildMerged
            ).run()
            print(receipt.canonical)
            print(
                "coherence: verdict \(receipt.verdict.rawValue), digest \(receipt.digest)"
            )
            Process.Exit.normal(receipt.verdict.status)
        }
    }
}
