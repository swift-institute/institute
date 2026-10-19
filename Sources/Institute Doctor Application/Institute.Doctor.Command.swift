public import Command
public import Command_Schema
import Environment
import File_System
public import Institute_Doctor
public import Institute_Model
import Process

extension Institute.Doctor {
    /// `institute doctor` — report checkout facts.
    public struct Command: Sendable, Command_Schema.Command.`Protocol` {
        public var institute: Bool

        public init(institute: Bool = false) { self.institute = institute }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "doctor", abstract: "Report machine-checked checkout facts.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Flag(
                    \.institute,
                    name: .long(.literal("institute")),
                    help: .init(
                        abstract:
                            "Run the institute-internal doctor checks too, which discover the "
                            + "live GitHub organizations (needs an authenticated gh; "
                            + "~460 requests)."
                    )
                )
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
            let selection = try Institute.Selection.effective(at: root.checkout, in: configuration)
            let registry = try Institute.Peer.Registry.load(at: root.checkout)
            let report = await Institute.Doctor(
                root: root,
                configuration: configuration,
                selection: selection,
                peers: registry.peers,
                progress: .standardOutput
            ).run(access: institute ? .institute() : .contributor)
            print(report)
            Process.Exit.normal(report.status)
        }
    }
}
