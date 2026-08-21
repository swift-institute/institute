public import Institute_Continuous_Integration_Source
public import Institute_Model
public import Source_Execution
public import Source_Report

extension Institute.Source.Application {
    public func measure(
        cohort: Institute.Source.Workspace.Cohort,
        selected: [Institute.Source.Workspace.Row]? = nil,
        engines: Set<SourceDomain.Engine.ID>? = nil,
        preparation: Institute.Source.Preparation
    ) async throws(Institute.Error) -> SourceDomain.Report {
        let rows = selected ?? cohort.admitted
        let scope: SourceDomain.Report.Scope = selected == nil && engines == nil ? .workspace : .partial
        let policy = Institute.ContinuousIntegration.Source.Policy.current
        guard preparation.policyRevision == policy.revision else {
            return .init(scope: scope, profile: .init("stale"), subjects: [], references: [.init(code: "stale-profile", detail: preparation.policyRevision)], measurements: [])
        }
        guard try Self.digest(file: preparation.swiftFormatExecutable) == preparation.swiftFormatTool,
            try Self.digest(file: preparation.linterExecutable) == preparation.linterTool
        else {
            return .init(scope: scope, profile: .init("stale"), subjects: [], references: [.init(code: "stale-tool", detail: preparation.directory)], measurements: [])
        }

        let drivers: [SourceDomain.Engine.Driver] = [
            .swiftFormat(process: process), .linter(process: process),
        ]
        let execution: SourceDomain.Execution
        do throws(SourceDomain.Execution.Error) { execution = try .init(drivers: drivers) }
        catch { throw .configuration("cannot register source engines: \(error)") }
        var subjects: [SourceDomain.Subject] = []
        var measurements: [SourceDomain.Measurement] = []
        for row in rows {
            guard let repository = row.repository else { continue }
            let subject = try subject(for: row)
            subjects.append(subject)
            let bundle = Institute.Source.Profile(policy: policy).bundle(for: repository)
            let rules = Institute.Source.Profile(policy: policy).rules(for: bundle)
            let linterConfiguration = "\(preparation.directory)/\(bundle.rawValue)-source-linter-profile.json"
            let profile = policy.profile(
                swiftFormatExecutable: preparation.swiftFormatExecutable,
                swiftFormatTool: preparation.swiftFormatTool,
                swiftFormatConfigurationPath: "\(preparation.directory)/.swift-format",
                linterExecutable: preparation.linterExecutable,
                linterTool: preparation.linterTool,
                linterConfigurationPath: linterConfiguration,
                bundle: bundle,
                linterRules: rules
            )
            guard preparation.profiles[bundle.rawValue] == profile.digest else {
                measurements.append(contentsOf: profile.engines.map {
                    .init(engine: $0.id, subject: subject, activeRules: $0.rules, applicableRules: [], files: subject.files, verdict: .unmeasured([.init(code: "stale-profile", detail: bundle.rawValue)]))
                })
                continue
            }
            measurements.append(contentsOf: await execution.measure(subject, profile: profile, engines: engines))
        }
        let digest = SourceDomain.Profile.Digest(
            preparation.profiles.keys.sorted().compactMap { preparation.profiles[$0]?.hex }.joined(separator: ":")
        )
        return .init(
            scope: scope,
            profile: digest,
            subjects: subjects,
            references: cohort.reasons,
            measurements: measurements
        )
    }
}
