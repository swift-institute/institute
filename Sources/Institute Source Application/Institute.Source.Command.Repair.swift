public import Command
public import Institute_Model

extension Institute.Source.Command {
    public enum Repair: Sendable, Command.`Protocol` {
        case plan(Plan)
        case apply(Apply)

        public init() { self = .plan(.init()) }

        public static var configuration: Command.Configuration {
            .init(name: "repair", abstract: "Plan or apply a source repair transaction.")
        }

        public static var schema: Command.Schema.Definition<Self> {
            .init {
                Command.Subcommand.Group {
                    Command.Subcommand.Case("plan", initial: { .init() }, map: Self.plan)
                    Command.Subcommand.Case("apply", initial: { .init() }, map: Self.apply)
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            switch self {
            case .plan(var command):
                try await command.run()
                self = .plan(command)
            case .apply(var command):
                try await command.run()
                self = .apply(command)
            }
        }
    }
}
