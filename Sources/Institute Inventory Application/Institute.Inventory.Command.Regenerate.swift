public import Command
public import Command_Schema
public import Institute_Inventory
public import Institute_Model

extension Institute.Inventory.Command {
    /// `institute inventory regenerate` — rediscover the Institute
    /// organizations through `gh` and rewrite `Institute.json` from
    /// ``Institute/Inventory/Policy/institute()``.
    ///
    /// The transport is `gh` (``Institute/Inventory/Transport/githubCLI``),
    /// which supplies the credential, so the application holds no HTTP
    /// client of its own.
    public struct Regenerate: Sendable, Command_Schema.Command.`Protocol` {
        public var dry: Bool

        public init(dry: Bool = false) { self.dry = dry }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "regenerate", abstract: "Rediscover the organizations and rewrite Institute.json.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Flag(
                    \.dry,
                    name: .long(.literal("dry-run")),
                    help: .init(
                        abstract: "Plan inventory regeneration without changing files."
                    )
                )
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let root = try Institute.Inventory.Command.root()
            let document = try Institute.Configuration.Document.load(at: root.checkout)
            let application = Institute.Inventory.Application(
                root: root.checkout,
                policy: .institute(),
                client: Institute.Inventory.client()
            )
            let plan: Institute.Inventory.Writer.Plan
            do throws(Institute.Inventory.Error<Institute.Inventory.Transport.Error>) {
                plan = try await application.run(existing: document, dry: dry)
            } catch {
                throw .configuration("inventory regenerate: \(error)")
            }
            switch plan {
            case .current:
                print("inventory regenerate: Institute.json is current")
            case .replace:
                print(
                    dry
                        ? "inventory regenerate: would replace Institute.json"
                        : "inventory regenerate: replaced Institute.json"
                )
            }
        }
    }
}
