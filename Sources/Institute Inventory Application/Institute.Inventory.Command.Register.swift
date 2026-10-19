public import Command
public import Command_Schema
public import Institute_Inventory
public import Institute_Model

extension Institute.Inventory.Command {
    /// `institute inventory` — the read-only register and peer report.
    public struct Register: Sendable, Command_Schema.Command.`Protocol` {
        public init() {}

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "register", abstract: "Print the read-only inventory register.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init(nodes: [])
        }

        public mutating func run() async throws(Institute.Error) {
            let root = try Institute.Inventory.Command.root()
            let configuration = try Institute.Configuration.load(at: root.checkout)
            print(
                Institute.Inventory.Register(
                    repositories: configuration.repositories
                )
            )
            let registry = try Institute.Peer.Registry.load(at: root.checkout)
            for peer in registry.peers {
                let presence: Institute.Peer.Presence
                do throws(Institute.Error) {
                    presence = .resolve(peer, at: try root.peer(peer))
                } catch {
                    presence = .invalid("\(error)")
                }
                print(Institute.Peer.Report(peer: peer, presence: presence))
            }
        }
    }
}
