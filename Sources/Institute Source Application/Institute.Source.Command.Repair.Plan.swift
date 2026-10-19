public import Command
public import Institute_Model
public import Institute_Source
public import Institute_Source_Workspace
public import Process
public import Source_Measurement
public import Source_Repair

extension Institute.Source.Command.Repair {
    public struct Plan: Sendable, Command.`Protocol` {
        public var workspacePath: Swift.String
        public var changed: Swift.Bool
        public var packagePaths: [Swift.String]
        public var rules: [Swift.String]
        public var outputPath: Swift.String

        public init(
            workspacePath: Swift.String = "",
            changed: Swift.Bool = false,
            packagePaths: [Swift.String] = [],
            rules: [Swift.String] = [],
            outputPath: Swift.String = ""
        ) {
            self.workspacePath = workspacePath
            self.changed = changed
            self.packagePaths = packagePaths
            self.rules = rules
            self.outputPath = outputPath
        }

        public static var configuration: Command.Configuration {
            .init(
                name: "plan",
                abstract: "Plan a transactional source repair without writing source."
            )
        }

        public static var schema: Command.Schema.Definition<Self> {
            .init {
                Command.Option(
                    \.workspacePath,
                    name: .long(.literal("workspace-path")),
                    placeholder: "workspace.xcworkspace"
                )
                Command.Flag(\.changed, name: .long(.literal("changed")))
                Command.Option<Self, Swift.String>.Many(
                    \.packagePaths,
                    name: .long(.literal("package-path")),
                    placeholder: "member"
                )
                Command.Option<Self, Swift.String>.Many(
                    \.rules,
                    name: .long(.literal("rule")),
                    placeholder: "engine:rule"
                )
                Command.Option(
                    \.outputPath,
                    name: .long(.literal("output-path")),
                    placeholder: "plan"
                )
            }
        }

        public mutating func validate() throws(Command.Error) {
            guard !workspacePath.isEmpty else {
                throw .validationFailed(reason: "--workspace-path is required")
            }
            guard !outputPath.isEmpty else {
                throw .validationFailed(reason: "--output-path is required")
            }
            guard !changed || packagePaths.isEmpty else {
                throw .validationFailed(
                    reason: "--changed and --package-path are mutually exclusive"
                )
            }
            guard Set(packagePaths).count == packagePaths.count else {
                throw .validationFailed(reason: "duplicate --package-path")
            }
            guard Set(rules).count == rules.count else {
                throw .validationFailed(reason: "duplicate --rule")
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let context = try Institute.Source.Command.context(workspace: workspacePath)
            let selection =
                changed
                ? await context.cohort.changed()
                : .init(
                    rows: try Institute.Source.Command.rows(
                        at: packagePaths,
                        in: context.cohort
                    ) ?? context.cohort.measurable,
                    reasons: []
                )
            guard selection.reasons.isEmpty else {
                for reason in selection.reasons {
                    print("UNMEASURED \(reason.code): \(reason.detail)")
                }
                Process.Exit.normal(2)
            }
            let plan = try await Institute.Source.Application().planRepair(
                workspace: workspacePath,
                configuration: context.configuration,
                cohort: context.cohort,
                members: selection.rows,
                rules: try Institute.Source.Command.rules(rules),
                preparation: try Institute.Source.Command.preparation(workspace: workspacePath)
            )
            try Institute.Source.Command.write(plan, to: outputPath)
            Process.Exit.normal(plan.repairs.contains { !$0.refusals.isEmpty } ? 1 : 0)
        }
    }
}
