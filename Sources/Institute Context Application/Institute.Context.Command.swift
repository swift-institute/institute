public import Command
public import Command_Schema
import Environment
import File_System
public import Institute_Development
public import Institute_Model
import Process

extension Institute.Context.Command {
    /// Resolves the loaded Institute context from the working directory.
    static func context() throws(Institute.Error) -> Institute.Context {
        guard let working = Environment.read("PWD") else {
            throw .configuration("PWD is not available")
        }
        let checkout: File.Directory
        do throws(File.Path.Error) {
            checkout = try File.Directory(validating: working)
        } catch {
            throw .configuration("Institute checkout is not a valid path: \(error)")
        }
        let root = try Institute.Root(checkout: checkout)
        return try Institute.Context(root: root)
    }
}

extension Institute.Context.Command {
    /// `institute context install` — install the canonical context files.
    public struct Install: Sendable, Command_Schema.Command.`Protocol` {
        public init() {}

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "install", abstract: "Install the canonical context files.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init(nodes: [])
        }

        public mutating func run() async throws(Institute.Error) {
            let context = try Institute.Context.Command.context()
            print(try context.install().summary)
        }
    }

    /// `institute context check` — verify the installed context files.
    public struct Check: Sendable, Command_Schema.Command.`Protocol` {
        public init() {}

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "check", abstract: "Verify the installed context files.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init(nodes: [])
        }

        public mutating func run() async throws(Institute.Error) {
            let context = try Institute.Context.Command.context()
            let diagnostics = try context.diagnostics()
            guard diagnostics.isEmpty else {
                throw .configuration(diagnostics.joined(separator: "\n"))
            }
            print("context: current")
        }
    }

    /// `institute context packet` — render one issue's current context.
    public struct Packet: Sendable, Command_Schema.Command.`Protocol` {
        public var issue: Swift.String
        public var maxBytes: Swift.Int
        public var includedComments: [Swift.String]
        public var output: Swift.String

        public init(
            issue: Swift.String = "",
            maxBytes: Swift.Int = 24_000,
            includedComments: [Swift.String] = [],
            output: Swift.String = ""
        ) {
            self.issue = issue
            self.maxBytes = maxBytes
            self.includedComments = includedComments
            self.output = output
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "packet", abstract: "Render one issue's current context packet.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.issue,
                    name: .long(.literal("issue")),
                    placeholder: "owner/repository#N",
                    help: .init(
                        abstract: "Issue whose current context is rendered."
                    )
                )
                Command_Schema.Command.Option(
                    \.maxBytes,
                    name: .long(.literal("max-bytes")),
                    placeholder: "n",
                    help: .init(
                        abstract: "Maximum rendered packet bytes (defaults to 24000)."
                    )
                )
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.includedComments,
                    name: .long(.literal("include-comment")),
                    placeholder: "URL",
                    help: .init(
                        abstract: "Explicit Issue comment URL to include (repeatable)."
                    )
                )
                Command_Schema.Command.Option(
                    \.output,
                    name: .long(.literal("format")),
                    placeholder: "human|json",
                    help: .init(
                        abstract:
                            "Render a concise human summary or deterministic JSON "
                            + "(defaults to human)."
                    )
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard Institute.Context.Packet.Key(argument: issue) != nil else {
                throw .validationFailed(
                    reason: "context packet requires --issue owner/repository#N."
                )
            }
            guard maxBytes >= 512 else {
                throw .validationFailed(
                    reason: "context packet --max-bytes must be at least 512."
                )
            }
            guard output.isEmpty || output == "human" || output == "json" else {
                throw .validationFailed(reason: "--format must be human or json.")
            }
        }

        public mutating func run() async throws(Institute.Error) {
            // The packet is remote-read; the checkout is still resolved so
            // an invocation outside a checkout refuses the same way every
            // context verb does.
            _ = try Institute.Context.Command.context()
            guard let key = Institute.Context.Packet.Key(argument: issue) else {
                throw .configuration("context packet requires --issue owner/repository#N.")
            }
            let result = await Institute.Context.Packet.Remote.client().record(
                key,
                includedComments
            )
            let report: Institute.Context.Packet.Report
            switch result {
            case .available(let record):
                report = .init(record: record, diagnostics: [], maxBytes: maxBytes)

            case .unavailable(let reason), .malformed(let reason), .unmeasured(let reason):
                report = .init(record: nil, diagnostics: [reason], maxBytes: maxBytes)
            }
            let format: Institute.Context.Packet.Output = output == "json" ? .json : .human
            print(report.render(format), terminator: "")
            Process.Exit.normal(report.status)
        }
    }
}

extension Institute.Context {
    /// `institute context` — the context verbs.
    public enum Command: Sendable, Command_Schema.Command.`Protocol` {
        case install(Install)
        case check(Check)
        case packet(Packet)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "context", abstract: "Install, verify, and read agent context.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "install",
                        help: .init(abstract: "Install the canonical context files."),
                        initial: { .init() },
                        map: Self.install
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "check",
                        help: .init(abstract: "Verify the installed context files."),
                        initial: { .init() },
                        map: Self.check
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "packet",
                        help: .init(abstract: "Render one issue's current context packet."),
                        initial: { .init() },
                        map: Self.packet
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
            case .packet(var command):
                try await command.run()
                self = .packet(command)
            }
        }
    }
}
