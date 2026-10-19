public import Command
public import Institute_Model
public import Institute_Source
public import Institute_Source_Workspace
public import Process
public import Source_Repair
public import Source_Report

extension Institute.Source.Command.Repair {
    public struct Apply: Sendable, Command.`Protocol` {
        public var workspacePath: Swift.String
        public var planPath: Swift.String
        public var format: Institute.Source.Command.Measure.Format
        public var outputPath: Swift.String

        public init(
            workspacePath: Swift.String = "",
            planPath: Swift.String = "",
            format: Institute.Source.Command.Measure.Format = .human,
            outputPath: Swift.String = ""
        ) {
            self.workspacePath = workspacePath
            self.planPath = planPath
            self.format = format
            self.outputPath = outputPath
        }

        public static var configuration: Command.Configuration {
            .init(name: "apply", abstract: "Apply one prevalidated source repair transaction.")
        }

        public static var schema: Command.Schema.Definition<Self> {
            .init {
                Command.Option(
                    \.workspacePath,
                    name: .long(.literal("workspace-path")),
                    placeholder: "workspace.xcworkspace"
                )
                Command.Option(\.planPath, name: .long(.literal("plan-path")), placeholder: "plan")
                Command.Option(\.format, name: .long(.literal("format")), placeholder: "human|json")
                Command.Option(
                    \.outputPath,
                    name: .long(.literal("output-path")),
                    placeholder: "report"
                )
            }
        }

        public mutating func validate() throws(Command.Error) {
            guard !workspacePath.isEmpty else {
                throw .validationFailed(reason: "--workspace-path is required")
            }
            guard !planPath.isEmpty else {
                throw .validationFailed(reason: "--plan-path is required")
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let context = try Institute.Source.Command.context(workspace: workspacePath)
            let plan = try Institute.Source.Command.repairPlan(at: planPath)
            let preparation = try Institute.Source.Command.preparation(workspace: workspacePath)
            let application = Institute.Source.Application()
            let refusal = try application.applyRepair(
                plan,
                workspace: workspacePath,
                configuration: context.configuration,
                cohort: context.cohort,
                preparation: preparation
            )
            let identities = Swift.Set(plan.repairs.map(\.subject.identity))
            let selected = context.cohort.measurable.filter { identities.contains($0.identity) }
            let report = try await application.measure(
                cohort: context.cohort,
                selected: selected,
                preparation: preparation
            )
            try Institute.Source.Command.write(report, format: format, to: outputPath)
            let status = Source_Report.Source.Report.Status(report, expected: report.commitment)
            Process.Exit.normal(refusal == nil ? status.code : 1)
        }
    }
}
