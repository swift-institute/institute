public import Command
public import Command_Schema
import Institute_Development
public import Institute_Model

extension Institute.Workspace.Command {
    /// `institute install` — install and verify the managed executable.
    public struct Install: Sendable, Command_Schema.Command.`Protocol` {
        public init() {}

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "install", abstract: "Install and verify the managed executable.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init(nodes: [])
        }

        public mutating func run() async throws(Institute.Error) {
            let installation = try Institute.Installation()
            try installation.install()
            print("institute: installed and verified")
            print("institute command: \(installation.command)")
            print("institute executable: \(installation.executable)")
        }
    }
}
