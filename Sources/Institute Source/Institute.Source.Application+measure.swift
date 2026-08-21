public import Async_Fanout
public import FIPS_180_4
public import Institute_Continuous_Integration_Source
public import Institute_Model
public import Source_Execution
public import Source_Report

extension Institute.Source.Application {
    public func measure(
        cohort: Institute.Source.Workspace.Cohort,
        selected: [Institute.Source.Workspace.Row]? = nil,
        engines: Set<SourceDomain.Engine.ID>? = nil,
        jobs: Swift.Int? = nil,
        references: [SourceDomain.Reason] = [],
        preparation: Institute.Source.Preparation
    ) async throws(Institute.Error) -> SourceDomain.Report {
        let rows = selected ?? cohort.admitted
        let scope: SourceDomain.Report.Scope = selected == nil && engines == nil ? .workspace : .partial
        let policy = ContinuousIntegration.Source.Policy.current
        guard preparation.policyRevision == policy.revision else {
            return .init(scope: scope, profile: .init("stale"), subjects: [], references: [.init(code: "stale-profile", detail: preparation.policyRevision)], measurements: [])
        }
        guard Self.matches(file: preparation.swiftFormatExecutable, digest: preparation.swiftFormatTool),
            Self.matches(file: preparation.linterExecutable, digest: preparation.linterTool)
        else {
            return .init(scope: scope, profile: .init("stale"), subjects: [], references: [.init(code: "stale-tool", detail: preparation.directory)], measurements: [])
        }
        guard Self.matches(
            file: "\(preparation.directory)/.swift-format",
            digest: policy.swiftFormat.digest
        )
        else {
            return .init(scope: scope, profile: .init("stale"), subjects: [], references: [.init(code: "stale-configuration", detail: ".swift-format")], measurements: [])
        }

        let drivers: [SourceDomain.Engine.Driver] = [
            .swiftFormat(process: process), .linter(process: process),
        ]
        let execution: SourceDomain.Execution
        do throws(SourceDomain.Execution.Error) { execution = try .init(drivers: drivers) }
        catch { throw .configuration("cannot register source engines: \(error)") }
        var subjects: [SourceDomain.Subject] = []
        var entries: [(
            repository: Institute.Repository,
            subject: SourceDomain.Subject
        )] = []
        for row in rows {
            guard let repository = row.repository else { continue }
            let subject = try subject(for: row)
            subjects.append(subject)
            entries.append((repository: repository, subject: subject))
        }
        let measurements = await Async.Fanout(jobs: jobs).mapAsync(entries) { entry in
            let subject = entry.subject
            let repository = entry.repository
            let bundle = Institute.Source.Profile(policy: policy).bundle(for: repository)
            let rules = Institute.Source.Profile(policy: policy).rules(for: bundle)
            let linterConfiguration = "\(preparation.directory)/\(bundle.rawValue)-source-linter-profile.json"
            let linterArtifact = policy.linter(bundle: bundle, rules: rules)
            guard Self.matches(file: linterConfiguration, digest: linterArtifact.digest) else {
                return policy.requiredEngines.map {
                    .init(engine: $0, subject: subject, activeRules: [], applicableRules: [], files: subject.files, verdict: .unmeasured([.init(code: "stale-configuration", detail: linterConfiguration)]))
                }
            }
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
                return profile.engines.map {
                    .init(engine: $0.id, subject: subject, activeRules: $0.rules, applicableRules: [], files: subject.files, verdict: .unmeasured([.init(code: "stale-profile", detail: bundle.rawValue)]))
                }
            }
            return await execution.measure(subject, profile: profile, engines: engines)
        }.flatMap { $0 }
        let profileBytes = preparation.profiles.keys.sorted()
            .compactMap { preparation.profiles[$0]?.hex }
            .joined(separator: ":").utf8.map(Byte.init)
        let digest = SourceDomain.Profile.Digest(FIPS_180_4.SHA256.digest(profileBytes).hex)
        return .init(
            scope: scope,
            profile: digest,
            subjects: subjects,
            references: cohort.reasons + references,
            measurements: measurements
        )
    }
}
