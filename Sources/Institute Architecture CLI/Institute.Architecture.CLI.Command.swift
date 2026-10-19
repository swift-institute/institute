public import Command
public import Command_Schema
import Environment
public import Institute_Architecture_Model
public import Institute_Model
import Process

extension Institute.Architecture.CLI {
    /// Which architecture verb one invocation performs.
    public enum Action: Sendable, Equatable, Argument.Codable {
        case validate
        case index

        public init?(argument: Swift.String) {
            switch argument {
            case "validate": self = .validate
            case "index": self = .index
            default: return nil
            }
        }

        public var argumentDescription: Swift.String {
            switch self {
            case .validate: "validate"
            case .index: "index"
            }
        }
    }

    /// `institute architecture validate|index` — the architecture gates.
    public struct Command: Sendable, Command_Schema.Command.`Protocol` {
        public var modes: [Action]
        public var workspacePath: Swift.String

        public init(modes: [Action] = [], workspacePath: Swift.String = "") {
            self.modes = modes
            self.workspacePath = workspacePath
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "architecture", abstract: "Validate or index the architecture record.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Positional<Self, Action>.Many(
                    \.modes,
                    name: "mode",
                    placeholder: "validate|index",
                    arity: .atMost(1),
                    help: .init(abstract: "Architecture operation to perform.")
                )
                Command_Schema.Command.Option(
                    \.workspacePath,
                    name: .long(.literal("workspace-path")),
                    placeholder: "path",
                    help: .init(
                        abstract: "Institute checkout this invocation resolves against."
                    )
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard modes.count == 1 else {
                throw .validationFailed(
                    reason: "architecture operation must be validate or index."
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let path: Swift.String
            if workspacePath.isEmpty {
                guard let working = Environment.read("PWD") else {
                    throw .configuration("PWD is not available")
                }
                path = working
            } else {
                path = workspacePath
            }
            let status: Swift.Int32
            do throws(Institute.Architecture.CLI.Error) {
                switch modes.first {
                case .validate:
                    status = try Institute.Architecture.CLI.validate(path: path)

                case .index:
                    status = try Institute.Architecture.CLI.index(path: path)

                case nil:
                    throw .configuration("architecture operation must be validate or index")
                }
            } catch {
                throw .configuration(
                    "architecture \(modes.first?.argumentDescription ?? "unknown"): \(error)"
                )
            }
            Process.Exit.normal(status)
        }
    }
}
