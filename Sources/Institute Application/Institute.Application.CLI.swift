public import Command
public import Command_Schema
public import Institute_Architecture_CLI
public import Institute_Architecture_Model
public import Institute_CI_Application
public import Institute_CI_Model
public import Institute_Certification_Application
public import Institute_Coherence_Application
public import Institute_Composition_Application
public import Institute_Context_Application
public import Institute_Conversion
public import Institute_Conversion_Application
public import Institute_Dependency
public import Institute_Dependency_Application
public import Institute_Development
public import Institute_Doctor
public import Institute_Doctor_Application
public import Institute_GitHub
public import Institute_GitHub_Application
public import Institute_Instruments
public import Institute_Inventory
public import Institute_Inventory_Application
public import Institute_Model
public import Institute_Package_Application
public import Institute_Planner_Application
public import Institute_Repository_Application
public import Institute_Repository_Policy
public import Institute_Source_Application
public import Institute_Verification_Application
public import Institute_Workspace_Application

extension Institute.Application {
    /// The Institute command router: one typed subcommand per family
    /// verb, and nothing else. Every option, every validation, and every
    /// execution body lives with its family; this type only names the
    /// grammar's first token.
    public enum CLI: Sendable, Command_Schema.Command.`Protocol` {
        case install(Institute.Workspace.Command.Install)
        case sync(Institute.Workspace.Command.Sync)
        case workspace(Institute.Workspace.Command)
        case build(Institute.Workspace.Command.Build)
        case doctor(Institute.Doctor.Command)
        case inventory(Institute.Inventory.Command)
        case dependencies(Institute.Dependency.Command)
        case composition(Institute.Composition.Command)
        case context(Institute.Context.Command)
        case package(Institute.Package.Command)
        case coherence(Institute.Coherence.Command)
        case conversion(Institute.Conversion.Command)
        case github(Institute.GitHub.Command)
        case verification(Institute.Verification.Command)
        case certification(Institute.Certification.Command)
        case ci(Institute.CI.Command)
        case planner(Institute.Planner.Command)
        case repository(Institute.Repository.Policy.Command)
        case architecture(Institute.Architecture.CLI.Command)
        case source(Institute.Source.Command)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(
                name: "institute",
                abstract: "Synchronize, diagnose, and operate the public Swift Institute workspace."
            )
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "install",
                        help: .init(abstract: "Install and verify the managed executable."),
                        initial: { .init() },
                        map: Self.install
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "sync",
                        help: .init(abstract: "Clone and fast-forward the effective selection."),
                        initial: { .init() },
                        map: Self.sync
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "workspace",
                        help: .init(abstract: "Maintain the materialized fleet workspace."),
                        initial: { .materialize(.init()) },
                        map: Self.workspace
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "build",
                        help: .init(abstract: "Build the whole selection in one xcodebuild."),
                        initial: { .init() },
                        map: Self.build
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "doctor",
                        help: .init(abstract: "Report machine-checked checkout facts."),
                        initial: { .init() },
                        map: Self.doctor
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "inventory",
                        help: .init(abstract: "Read and derive the package inventory."),
                        initial: { .register(.init()) },
                        map: Self.inventory
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "dependencies",
                        help: .init(abstract: "Audit every declared dependency edge."),
                        initial: { .init() },
                        map: Self.dependencies
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "compose",
                        help: .init(abstract: "Compose a consumer onto a local dependency."),
                        initial: { .init(action: .compose) },
                        map: Self.composition
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "restore",
                        help: .init(abstract: "Restore a composed consumer manifest."),
                        initial: { .init(action: .restore) },
                        map: Self.composition
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "verify",
                        help: .init(abstract: "Verify a consumer against a local dependency."),
                        initial: { .init(action: .verify) },
                        map: Self.composition
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "context",
                        help: .init(abstract: "Install, verify, and read agent context."),
                        initial: { .install(.init()) },
                        map: Self.context
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "package",
                        help: .init(abstract: "Operate one package via the build coordinator."),
                        initial: { .execute(.init()) },
                        map: Self.package
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "coherence",
                        help: .init(abstract: "Measure the whole selection's coherence."),
                        initial: { .init() },
                        map: Self.coherence
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "conversion",
                        help: .init(abstract: "Seal and verify the conversion receipt."),
                        initial: { .seal(.init()) },
                        map: Self.conversion
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "github",
                        help: .init(abstract: "Mint GitHub App installation credentials."),
                        initial: { .token(.init()) },
                        map: Self.github
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "verification",
                        help: .init(abstract: "Seal and verify verification receipts."),
                        initial: { .seal(.init()) },
                        map: Self.verification
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "certification",
                        help: .init(abstract: "Derive, execute, and assemble certification."),
                        initial: { .snapshot(.init()) },
                        map: Self.certification
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "ci",
                        help: .init(abstract: "Operate the reabsorbed Institute.CI domain."),
                        initial: { .init() },
                        map: Self.ci
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "planner",
                        help: .init(abstract: "Canary and adopt a published CI planner."),
                        initial: { .canary(.init()) },
                        map: Self.planner
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "repository",
                        help: .init(abstract: "Operate the repository-policy families."),
                        initial: { .init() },
                        map: Self.repository
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "architecture",
                        help: .init(abstract: "Validate or index the architecture record."),
                        initial: { .init() },
                        map: Self.architecture
                    )
                    Command_Schema.Command.Subcommand.Case(
                        "source",
                        help: .init(abstract: "Measure and repair the workspace source cohort."),
                        initial: { .prepare(.init()) },
                        map: Self.source
                    )
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            switch self {
            case .install(var command):
                try await command.run()
                self = .install(command)
            case .sync(var command):
                try await command.run()
                self = .sync(command)
            case .workspace(var command):
                try await command.run()
                self = .workspace(command)
            case .build(var command):
                try await command.run()
                self = .build(command)
            case .doctor(var command):
                try await command.run()
                self = .doctor(command)
            case .inventory(var command):
                try await command.run()
                self = .inventory(command)
            case .dependencies(var command):
                try await command.run()
                self = .dependencies(command)
            case .composition(var command):
                try await command.run()
                self = .composition(command)
            case .context(var command):
                try await command.run()
                self = .context(command)
            case .package(var command):
                try await command.run()
                self = .package(command)
            case .coherence(var command):
                try await command.run()
                self = .coherence(command)
            case .conversion(var command):
                try await command.run()
                self = .conversion(command)
            case .github(var command):
                try await command.run()
                self = .github(command)
            case .verification(var command):
                try await command.run()
                self = .verification(command)
            case .certification(var command):
                try await command.run()
                self = .certification(command)
            case .ci(var command):
                try await command.run()
                self = .ci(command)
            case .planner(var command):
                try await command.run()
                self = .planner(command)
            case .repository(var command):
                try await command.run()
                self = .repository(command)
            case .architecture(var command):
                try await command.run()
                self = .architecture(command)
            case .source(var command):
                try await command.run()
                self = .source(command)
            }
        }
    }
}
