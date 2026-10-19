public import Command
public import Command_Schema
import Environment
import File_System
public import Institute_Inventory
public import Institute_Model

extension Institute.Inventory.Command {
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

extension Institute.Inventory {
    /// `institute inventory` — the inventory verbs; without one, the
    /// read-only register.
    public enum Command: Sendable, Command_Schema.Command.`Protocol` {
        case register(Register)
        case regenerate(Regenerate)
        case effective(Effective)
        case pages(Pages)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "inventory", abstract: "Read and derive the package inventory.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "register",
                        help: .init(abstract: "Print the read-only inventory register."),
                        initial: { .init() },
                        map: Self.register
                    ).default
                    Command_Schema.Command.Subcommand.Case(
                        "regenerate",
                        help: .init(abstract: "Rediscover the organizations and rewrite Institute.json."),
                        initial: { .init() },
                        map: Self.regenerate
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "effective",
                        help: .init(abstract: "Derive and write the effective inventory."),
                        initial: { .init() },
                        map: Self.effective
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "pages",
                        help: .init(abstract: "Enumerate Pages posture over the selection."),
                        initial: { .init() },
                        map: Self.pages
                    )
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            switch self {
            case .register(var command):
                try await command.run()
                self = .register(command)
            case .regenerate(var command):
                try await command.run()
                self = .regenerate(command)
            case .effective(var command):
                try await command.run()
                self = .effective(command)
            case .pages(var command):
                try await command.run()
                self = .pages(command)
            }
        }
    }
}
