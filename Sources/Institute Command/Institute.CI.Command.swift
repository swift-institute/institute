public import Command
public import Command_Schema
public import Institute_CI_Model
public import Institute_Model

extension Institute.CI {
    /// `institute ci` — the typed continuous-integration passthrough. The
    /// family owns its own argument grammar (`execute(_:)`); the router
    /// forwards the bare tokens.
    public struct Command: Sendable, Command_Schema.Command.`Protocol` {
        public var arguments: [Swift.String]

        public init(arguments: [Swift.String] = []) { self.arguments = arguments }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(
                name: "ci",
                abstract: "Operate the reabsorbed Institute.CI domain.",
                discussion: Source.usage
            )
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Positional<Self, Swift.String>.Many(
                    \.arguments,
                    name: "arguments",
                    placeholder: "ci-arguments",
                    arity: .atLeast(0),
                    help: .init(abstract: "Arguments forwarded to the CI family grammar.")
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            await Institute.CI.Command.execute(arguments)
        }
    }
}
