public import Command
public import Command_Schema
public import Institute_Model
public import Institute_Repository_Policy

extension Institute.Repository.Policy {
    /// `institute repository` — the typed repository-policy passthrough.
    /// The family owns its own argument grammar (`execute(_:)`); the
    /// router forwards the bare tokens.
    public struct Command: Sendable, Command_Schema.Command.`Protocol` {
        public var arguments: [Swift.String]

        public init(arguments: [Swift.String] = []) { self.arguments = arguments }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "repository", abstract: "Operate the repository-policy families.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Positional<Self, Swift.String>.Many(
                    \.arguments,
                    name: "arguments",
                    placeholder: "repository-arguments",
                    arity: .atLeast(0),
                    help: .init(abstract: "Arguments forwarded to the repository family grammar.")
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            await Institute.Repository.Policy.Command.execute(arguments)
        }
    }
}
