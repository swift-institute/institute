public import Command
public import Command_Schema
public import Institute_Model
public import Institute_Source

extension Institute.Source {
    public enum Command: Sendable, Command_Schema.Command.`Protocol` {
        case prepare(Prepare)
        case measure(Measure)
        case repair(Repair)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "source", abstract: "Measure and repair the workspace source cohort.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "prepare",
                        help: .init(abstract: "Render and verify the local source profile."),
                        initial: { .init() },
                        map: Self.prepare
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "measure",
                        help: .init(abstract: "Measure source without building or testing."),
                        initial: { .init() },
                        map: Self.measure
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "repair",
                        help: .init(abstract: "Plan or apply a source repair transaction."),
                        initial: { .init() },
                        map: Self.repair
                    )
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            switch self {
            case .prepare(var command):
                try await command.run()
                self = .prepare(command)
            case .measure(var command):
                try await command.run()
                self = .measure(command)
            case .repair(var command):
                try await command.run()
                self = .repair(command)
            }
        }
    }
}
