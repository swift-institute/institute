public import Command
public import Command_Schema
import Environment
import File_System
import Git_Foundation
public import Institute_Dependency
import Institute_GitHub
import Institute_Inventory
public import Institute_Model
import Process

extension Institute.Dependency {
    /// `institute dependencies` — audit every declared dependency edge.
    public struct Command: Sendable, Command_Schema.Command.`Protocol` {
        public var output: Institute.Dependency.Output?
        public var sanctionedExceptions: [Swift.String]

        public init(
            output: Institute.Dependency.Output? = nil,
            sanctionedExceptions: [Swift.String] = []
        ) {
            self.output = output
            self.sanctionedExceptions = sanctionedExceptions
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "dependencies", abstract: "Audit every declared dependency edge.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
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
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.sanctionedExceptions,
                    name: .long(.literal("sanctioned-exception")),
                    placeholder: "owner/repository",
                    help: .init(
                        abstract:
                            "Classify this canonical repository identity as a policy-supplied "
                            + "sanctioned exception (repeatable)."
                    )
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            var exceptions = Set<Institute.Repository.Key>()
            for value in sanctionedExceptions {
                guard let key = Institute.Repository.Key(identity: value) else {
                    throw .validationFailed(
                        reason: "invalid sanctioned exception \(value); expected owner/repository."
                    )
                }
                guard exceptions.insert(key).inserted else {
                    throw .validationFailed(
                        reason: "duplicate sanctioned exception \(value)."
                    )
                }
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
            let git = Git.Client()
            let head: Git.Object.ID
            let dirty: Swift.Bool
            do throws(Git.Client.Error) {
                head = try git.head(at: root.checkout.description)
                dirty = try git.status(at: root.checkout.description).contains {
                    $0.path == [UInt8]("Institute.json".utf8)
                }
            } catch {
                throw .process("cannot identify the Institute.json source revision: \(error)")
            }
            guard !dirty else {
                throw .configuration(
                    "Institute.json has working-tree changes; an exact source revision "
                        + "cannot be recorded"
                )
            }
            let exceptions = Set(
                sanctionedExceptions.compactMap(Institute.Repository.Key.init(identity:))
            )
            let report = await Institute.Dependency.Audit(
                repositories: configuration.repositories,
                policy: .institute(),
                client: Institute.Dependency.Remote.client(),
                sanctioned: exceptions,
                inventoryReference: "HEAD",
                inventoryRevision: head.rawValue
            ).run()
            switch output ?? .human {
            case .human: print(report)
            case .json: print(report.json, terminator: "")
            }
            Process.Exit.normal(report.status)
        }
    }
}
