public import Command
public import Command_Schema
import Environment
import File_System
public import Institute_Model

extension Institute.Planner {
    /// `institute planner` — the coordinator verbs over the planner
    /// release chain: `canary` judges a publish run against the current
    /// planner, `adopt` records an adoptable one as a local commit in the
    /// consumer checkout. Neither pushes.
    public enum Command: Sendable, Command_Schema.Command.`Protocol` {
        case canary(Canary)
        case adopt(Adopt)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "planner", abstract: "Canary and adopt a published CI planner.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "canary",
                        help: .init(abstract: "Run a published planner against the current one."),
                        initial: { .init() },
                        map: Self.canary
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "adopt",
                        help: .init(abstract: "Commit an adoptable planner to the consumer checkout."),
                        initial: { .init() },
                        map: Self.adopt
                    )
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            switch self {
            case .canary(var command):
                try await command.run()
                self = .canary(command)
            case .adopt(var command):
                try await command.run()
                self = .adopt(command)
            }
        }
    }
}

extension Institute.Planner.Command {
    /// Resolves the Institute root from the working directory.
    static func root() throws(Institute.Error) -> Institute.Root {
        guard let working = Environment.read("PWD") else {
            throw .configuration("PWD is not available")
        }
        let checkout: File.Directory
        do throws(File.Path.Error) {
            checkout = try File.Directory(validating: working)
        } catch {
            throw .configuration("Institute checkout is not a valid path: \(error)")
        }
        return try Institute.Root(checkout: checkout)
    }
}
