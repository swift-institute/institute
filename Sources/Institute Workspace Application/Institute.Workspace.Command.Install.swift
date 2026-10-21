public import Command
public import Command_Schema
import Institute_Development
public import Institute_Model
import Institute_Planner_Application

extension Institute.Workspace.Command {
    /// `institute install` — install the published, digest-verified planner
    /// that swift-institute/.github pins for this platform, and record what
    /// was installed. It never builds.
    public struct Install: Sendable, Command_Schema.Command.`Protocol` {
        public init() {}

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "install", abstract: "Install the published planner pinned by the CI policy.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init(nodes: [])
        }

        public mutating func run() async throws(Institute.Error) {
            guard Institute.Planner.Platform.host == .macos else {
                throw .configuration(
                    "institute install is published for macos-arm64 only"
                )
            }
            let executable: Institute.Planner.Executable
            do throws(Institute.Planner.Error) {
                executable = try Institute.Planner.Pinned.executable(
                    consumer: .published,
                    release: .github,
                    platform: .macos
                )
            } catch {
                throw .configuration("institute install refused: \(error)")
            }
            let installation = try executable.install()
            print("institute: installed and verified the pinned planner")
            print(executable.identity, terminator: "")
            print("institute command: \(installation.command)")
            print("institute executable: \(installation.executable)")
        }
    }
}
