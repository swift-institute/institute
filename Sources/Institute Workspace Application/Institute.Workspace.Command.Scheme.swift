public import Command
public import Command_Schema
import File_System
import Institute_Development
public import Institute_Model
import Xcode_Workspace

extension Institute.Workspace.Command {
    /// `institute workspace scheme` — generate the one aggregate shared scheme
    /// for an existing typed Institute workspace.
    public struct Scheme: Sendable, Command_Schema.Command.`Protocol` {
        public var workspacePath: Swift.String
        public var jobs: Swift.Int?

        public init(workspacePath: Swift.String = "", jobs: Swift.Int? = nil) {
            self.workspacePath = workspacePath
            self.jobs = jobs
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(
                name: "scheme",
                abstract: "Generate the aggregate build-and-test scheme for a workspace."
            )
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.workspacePath,
                    name: .long(.literal("workspace-path")),
                    placeholder: "workspace.xcworkspace",
                    help: .init(abstract: "Existing Institute workspace to configure.")
                )
                Command_Schema.Command.Option(
                    \.jobs,
                    name: .long(.literal("jobs")),
                    placeholder: "n",
                    help: .init(abstract: "Cap concurrent manifest evaluations (defaults to 32).")
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard !workspacePath.isEmpty else {
                throw .validationFailed(reason: "this operation requires --workspace-path.")
            }
            guard jobs.map({ $0 > 0 }) ?? true else {
                throw .validationFailed(reason: "--jobs must be positive.")
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let supplied: File.Path
            do throws(File.Path.Error) {
                supplied = try .init(workspacePath)
            } catch {
                throw .configuration("invalid --workspace-path \(workspacePath)")
            }
            let path: File.Path
            do throws(File.System.Canonical.Error) {
                path = try File.System.Canonical.resolve(supplied)
            } catch {
                throw .configuration("cannot resolve --workspace-path \(workspacePath): \(error)")
            }
            let bundle = File.Directory(path)
            guard bundle[file: "contents.xcworkspacedata"].stat.isFile else {
                throw .configuration("--workspace-path is not an Xcode workspace: \(workspacePath)")
            }
            guard let checkout = bundle.parent else {
                throw .configuration("workspace has no containing Institute checkout")
            }
            let root = try Institute.Root(checkout: checkout)
            let configuration = try Institute.Configuration.load(at: root.checkout)
            let workspace: Xcode_Workspace.Xcode.Workspace
            do throws(Xcode_Workspace.Xcode.Workspace.Error) {
                workspace = try .read(from: bundle.description)
            } catch {
                throw .configuration("cannot read --workspace-path \(workspacePath): \(error)")
            }
            let specification = try Institute.Xcode.integration(
                workspace,
                repositories: configuration.repositories
            )
            let plan = try await Institute.Xcode.Scheme.plan(
                for: specification,
                at: root,
                fanout: .init(jobs: jobs ?? 32)
            )
            let wasCurrent = Institute.Xcode.Scheme.current(plan, in: bundle)
            if !wasCurrent {
                try Institute.Xcode.Scheme.write(plan, to: bundle)
            }
            print(
                "scheme: \(wasCurrent ? "current" : "generated"), "
                    + "\(plan.buildables.count) buildables, "
                    + "\(plan.testables.count) parallel testables"
            )
        }
    }
}
