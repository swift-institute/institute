public import Command
public import Command_Schema
import Environment
import File_System
public import Institute_Development
public import Institute_Model

extension Institute.Composition.Command {
    /// Which composition verb one invocation performs.
    public enum Action: Sendable, Equatable {
        case compose
        case restore
        case verify
    }
}

extension Institute.Composition {
    /// `institute compose|restore|verify` — one composition transaction.
    public struct Command: Sendable, Command_Schema.Command.`Protocol` {
        public var action: Action
        public var consumer: Swift.String
        public var dependency: Swift.String

        public init(
            action: Action = .compose,
            consumer: Swift.String = "",
            dependency: Swift.String = ""
        ) {
            self.action = action
            self.consumer = consumer
            self.dependency = dependency
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(
                name: "composition",
                abstract: "Compose, restore, or verify a local-source composition."
            )
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.consumer,
                    name: .long(.literal("consumer")),
                    placeholder: "repository",
                    help: .init(
                        abstract: "Institute repository whose manifest is composed."
                    )
                )
                Command_Schema.Command.Option(
                    \.dependency,
                    name: .long(.literal("dependency")),
                    placeholder: "repository",
                    help: .init(
                        abstract: "Institute repository redirected to a local source."
                    )
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard !consumer.isEmpty else {
                throw .validationFailed(reason: "this operation requires --consumer.")
            }
            guard !dependency.isEmpty else {
                throw .validationFailed(reason: "this operation requires --dependency.")
            }
        }

        public mutating func run() async throws(Institute.Error) {
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
            let configuration = try Institute.Configuration.load(at: root.checkout)
            let composition = Institute.Composition(root: root, configuration: configuration)
            switch action {
            case .compose:
                try composition.compose(consumer: consumer, dependency: dependency)

            case .restore:
                try composition.restore(consumer: consumer, dependency: dependency)

            case .verify:
                try composition.verify(consumer: consumer, dependency: dependency)
            }
        }
    }
}
