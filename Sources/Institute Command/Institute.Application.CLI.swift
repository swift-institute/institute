public import Command
public import Command_Schema
public import Institute_CI_Model
public import Institute_GitHub
public import Institute_Model
public import Institute_Planner
public import Institute_Repository_Policy

extension Institute.Application {
    /// The Institute command router: one typed subcommand per family
    /// verb, and nothing else. Every option, every validation, and every
    /// execution body lives with its family; this type only names the
    /// grammar's first token.
    public enum CLI: Sendable, Command_Schema.Command.`Protocol` {
        case install(Institute.Application.Install)
        case ci(Institute.CI.Command)
        case planner(Institute.Planner.Command)
        case repository(Institute.Repository.Policy.Command)
        case github(Institute.GitHub.Command)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(
                name: "institute",
                abstract: "Operate the Swift Institute's central CI and its GitHub organizations."
            )
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "install",
                        help: .init(abstract: "Install the published planner pinned by the CI policy."),
                        initial: { .init() },
                        map: Self.install
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "ci",
                        help: .init(abstract: "Run the CI planner verbs."),
                        initial: { .init() },
                        map: Self.ci
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "planner",
                        help: .init(abstract: "Canary and adopt a published CI planner."),
                        initial: { .canary(.init()) },
                        map: Self.planner
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "repository",
                        help: .init(abstract: "Operate the repository-policy families."),
                        initial: { .init() },
                        map: Self.repository
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "github",
                        help: .init(abstract: "Mint GitHub App installation credentials."),
                        initial: { .token(.init()) },
                        map: Self.github
                    )
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            switch self {
            case .install(var command):
                try await command.run()
                self = .install(command)
            case .ci(var command):
                try await command.run()
                self = .ci(command)
            case .planner(var command):
                try await command.run()
                self = .planner(command)
            case .repository(var command):
                try await command.run()
                self = .repository(command)
            case .github(var command):
                try await command.run()
                self = .github(command)
            }
        }
    }
}
