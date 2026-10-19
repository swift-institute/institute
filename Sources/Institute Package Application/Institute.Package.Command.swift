public import Command
public import Command_Schema
import Institute_Build_Coordinator
public import Institute_Model

extension Institute {
    /// The single-package operation domain: one package operated through
    /// the build coordinator.
    public enum Package {}
}

extension Institute.Package {
    /// `institute package` — the single-package verbs.
    public enum Command: Sendable, Command_Schema.Command.`Protocol` {
        case execute(Execute)
        case forward(Forward)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "package", abstract: "Operate one package via the build coordinator.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "build",
                        help: .init(abstract: "Build one package via the coordinator."),
                        initial: { Execute(action: .build) },
                        map: Self.execute
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "test",
                        help: .init(abstract: "Test one package via the coordinator."),
                        initial: { Execute(action: .test) },
                        map: Self.execute
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "run",
                        help: .init(abstract: "Run one package via the coordinator."),
                        initial: { Forward(action: .run) },
                        map: Self.forward
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "resolve",
                        help: .init(abstract: "Resolve one package via the coordinator."),
                        initial: { Forward(action: .resolve) },
                        map: Self.forward
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "update",
                        help: .init(abstract: "Update one package via the coordinator."),
                        initial: { Forward(action: .update) },
                        map: Self.forward
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "clean",
                        help: .init(abstract: "Clean one package via the coordinator."),
                        initial: { Forward(action: .clean) },
                        map: Self.forward
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "dump-package",
                        help: .init(abstract: "Dump one package manifest via the coordinator."),
                        initial: { Forward(action: .dumpPackage) },
                        map: Self.forward
                    )
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            switch self {
            case .execute(var command):
                try await command.run()
                self = .execute(command)
            case .forward(var command):
                try await command.run()
                self = .forward(command)
            }
        }
    }
}
