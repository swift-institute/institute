public import Command
public import Command_Schema
import Environment
import File_System
public import Institute_Development
public import Institute_Model

extension Institute.Navigation.Command {
    /// Resolves the navigation surface against a checkout: the supplied
    /// `--workspace-path` when present, the working directory otherwise.
    static func navigation(
        at workspacePath: Swift.String
    ) throws(Institute.Error) -> Institute.Navigation {
        let checkoutValue: Swift.String
        if workspacePath.isEmpty {
            guard let working = Environment.read("PWD") else {
                throw .configuration("PWD is not available")
            }
            checkoutValue = working
        } else {
            checkoutValue = workspacePath
        }
        let checkout: File.Directory
        do throws(File.Path.Error) {
            checkout = try File.Directory(validating: checkoutValue)
        } catch {
            throw .configuration("Institute checkout is not a valid path: \(error)")
        }
        let root = try Institute.Root(checkout: checkout)
        let configuration = try Institute.Configuration.load(at: root.checkout)
        return Institute.Navigation(root: root, configuration: configuration)
    }
}

extension Institute.Navigation.Command {
    /// `institute navigation install` — install and verify cclsp.
    public struct Install: Sendable, Command_Schema.Command.`Protocol` {
        public var workspacePath: Swift.String

        public init(workspacePath: Swift.String = "") { self.workspacePath = workspacePath }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "install", abstract: "Install and verify the navigation integration.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
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

        public mutating func run() async throws(Institute.Error) {
            let navigation = try Institute.Navigation.Command.navigation(at: workspacePath)
            try navigation.install()
            print("navigation: installed and verified")
            print("navigation MCP descriptor: \(navigation.descriptorFile)")
        }
    }

    /// `institute navigation check` — verify the installed integration.
    public struct Check: Sendable, Command_Schema.Command.`Protocol` {
        public var workspacePath: Swift.String

        public init(workspacePath: Swift.String = "") { self.workspacePath = workspacePath }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "check", abstract: "Verify the installed navigation integration.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
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

        public mutating func run() async throws(Institute.Error) {
            let navigation = try Institute.Navigation.Command.navigation(at: workspacePath)
            let diagnostics = try navigation.diagnostics()
            guard diagnostics.isEmpty else {
                throw .configuration(diagnostics.joined(separator: "\n"))
            }
            print("navigation: current")
        }
    }

    /// `institute navigation serve` — serve the navigation MCP boundary.
    public struct Serve: Sendable, Command_Schema.Command.`Protocol` {
        public init() {}

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "serve", abstract: "Serve the navigation MCP boundary.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init(nodes: [])
        }

        public mutating func run() async throws(Institute.Error) {
            try Institute.Navigation.serve()
        }
    }
}

extension Institute.Navigation {
    /// `institute navigation` — the navigation verbs.
    public enum Command: Sendable, Command_Schema.Command.`Protocol` {
        case install(Install)
        case check(Check)
        case serve(Serve)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "navigation", abstract: "Install, verify, and serve code navigation.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "install",
                        help: .init(abstract: "Install and verify the navigation integration."),
                        initial: { .init() },
                        map: Self.install
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "check",
                        help: .init(abstract: "Verify the installed navigation integration."),
                        initial: { .init() },
                        map: Self.check
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "serve",
                        help: .init(abstract: "Serve the navigation MCP boundary."),
                        initial: { .init() },
                        map: Self.serve
                    )
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            switch self {
            case .install(var command):
                try await command.run()
                self = .install(command)
            case .check(var command):
                try await command.run()
                self = .check(command)
            case .serve(var command):
                try await command.run()
                self = .serve(command)
            }
        }
    }
}
