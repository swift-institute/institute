public import Command
public import Command_Schema
import Institute_Development
public import Institute_Model

extension Institute.Workspace.Command {
    /// `institute sync` — clone and fast-forward the effective selection.
    public struct Sync: Sendable, Command_Schema.Command.`Protocol` {
        public var dry: Bool

        public init(dry: Bool = false) { self.dry = dry }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "sync", abstract: "Clone and fast-forward the effective selection.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Flag(
                    \.dry,
                    name: .long(.literal("dry-run")),
                    help: .init(
                        abstract:
                            "Plan synchronization without changing files or Git metadata."
                    )
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let root = try Institute.Workspace.Command.root()
            let configuration = try Institute.Configuration.load(at: root.checkout)
            let selection = try Institute.Selection.effective(at: root.checkout, in: configuration)
            try await Institute.Sync(root: root, selection: selection).run(dry: dry)
        }
    }
}
