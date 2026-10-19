public import Command
public import Command_Schema
import Institute_Development
public import Institute_Model
import Process

extension Institute.Workspace.Command {
    /// `institute build` — build the whole selection in one xcodebuild.
    public struct Build: Sendable, Command_Schema.Command.`Protocol` {
        public var fresh: Bool
        public var arguments: [Swift.String]

        public init(fresh: Bool = false, arguments: [Swift.String] = []) {
            self.fresh = fresh
            self.arguments = arguments
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "build", abstract: "Build the whole selection in one xcodebuild.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Flag(
                    \.fresh,
                    name: .long(.literal("fresh")),
                    help: .init(
                        abstract:
                            "Use isolated build state — a derived-data directory for the "
                            + "workspace build."
                    )
                )
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.arguments,
                    name: .long(.literal("argument")),
                    placeholder: "xcodebuild-argument",
                    help: .init(
                        abstract:
                            "Argument forwarded to xcodebuild (repeatable)."
                    )
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let root = try Institute.Workspace.Command.root()
            let configuration = try Institute.Configuration.load(at: root.checkout)
            let selection = try Institute.Selection.effective(at: root.checkout, in: configuration)
            print(selection.origin)
            let status = try await Institute.Xcode.Build(root: root, selection: selection)
                .run(fresh: fresh, arguments: arguments)
            Process.Exit.normal(status)
        }
    }
}
