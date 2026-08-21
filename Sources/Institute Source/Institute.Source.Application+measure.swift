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
        let rows = selected ?? cohort.measurable
        let scope: SourceDomain.Report.Scope =
            selected == nil && engines == nil ? .workspace : .partial
        let policy = ContinuousIntegration.Source.Policy.current
        guard preparation.policyRevision == policy.revision else {
            return Self.unmeasuredReport(
                scope: scope,
                reason: .init(code: "stale-profile", detail: preparation.policyRevision)
            )
        }
        guard
            Self.matches(
                file: preparation.swiftFormatExecutable,
                digest: preparation.swiftFormatTool
            ),
            Self.matches(file: preparation.linterExecutable, digest: preparation.linterTool)
        else {
            return Self.unmeasuredReport(
                scope: scope,
                reason: .init(code: "stale-tool", detail: preparation.directory)
            )
        }
        guard
            Self.matches(
                file: "\(preparation.directory)/.swift-format",
                digest: policy.swiftFormat.digest
            )
        else {
            return Self.unmeasuredReport(
                scope: scope,
                reason: .init(code: "stale-configuration", detail: ".swift-format")
            )
        }

        let drivers: [SourceDomain.Engine.Driver] = [
            .swiftFormat(process: process), .linter(process: process),
        ]
        let execution: SourceDomain.Execution
        do throws(SourceDomain.Execution.Error) { execution = try .init(drivers: drivers) } catch {
            throw .configuration("cannot register source engines: \(error)")
        }
        var subjects: [SourceDomain.Subject] = []
        var entries: [(row: Institute.Source.Workspace.Row, subject: SourceDomain.Subject)] = []
        for row in rows {
            let subject = try subject(for: row)
            subjects.append(subject)
            entries.append((row: row, subject: subject))
        }
        let owner = Institute.Source.Profile(policy: policy)
        var requirements: [SourceDomain.Report.Commitment.Requirement] = []
        for entry in entries {
            let bundle = try owner.bundle(for: entry.row)
            let artifacts = entry.subject.artifacts.filter { $0.kind == .swift }.map(\.path)
            for engine in policy.requiredEngines where engines?.contains(engine) ?? true {
                let rules: [SourceDomain.Rule.ID]
                switch engine.token {
                case "swift-format":
                    rules = [.init(engine: engine, token: "format")]
                case "swift-linter":
                    rules = owner.rules(for: bundle)
                default:
                    rules = []
                }
                requirements.append(
                    .init(
                        subject: entry.subject.identity,
                        engine: engine,
                        artifacts: artifacts,
                        rules: rules
                    )
                )
            }
        }
        let measurements = await Async.Fanout(jobs: jobs).mapAsync(entries) { entry in
            let subject = entry.subject
            let bundle: ContinuousIntegration.Source.Bundle
            do throws(Institute.Error) {
                bundle = try Institute.Source.Profile(policy: policy).bundle(for: entry.row)
            } catch {
                return policy.requiredEngines.map {
                    .init(
                        engine: $0,
                        subject: subject,
                        activeRules: [],
                        applicableRules: [],
                        files: subject.paths(of: .swift),
                        verdict: .unmeasured([.init(code: "profile-binding", detail: "\(error)")])
                    )
                }
            }
            let rules = Institute.Source.Profile(policy: policy).rules(for: bundle)
            let linterConfiguration =
                "\(preparation.directory)/\(bundle.rawValue)-source-linter-profile.json"
            let linterArtifact = policy.linter(bundle: bundle, rules: rules)
            guard Self.matches(file: linterConfiguration, digest: linterArtifact.digest) else {
                return policy.requiredEngines.map {
                    .init(
                        engine: $0,
                        subject: subject,
                        activeRules: [],
                        applicableRules: [],
                        files: subject.paths(of: .swift),
                        verdict: .unmeasured([
                            .init(code: "stale-configuration", detail: linterConfiguration)
                        ])
                    )
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
                    .init(
                        engine: $0.id,
                        subject: subject,
                        activeRules: $0.rules,
                        applicableRules: [],
                        files: subject.paths(of: .swift),
                        verdict: .unmeasured([.init(code: "stale-profile", detail: bundle.rawValue)]
                        )
                    )
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
            commitment: .init(
                subjects: subjects,
                engines: policy.requiredEngines.map {
                    .init(id: $0, artifactKinds: [.swift])
                },
                requirements: requirements,
                predicates: []
            ),
            subjects: subjects,
            references: cohort.reasons
                + Self.selfApplicationReasons(
                    cohort: cohort,
                    policy: policy
                ) + references,
            measurements: measurements,
            artifactEvidence: []
        )
    }

    private static func selfApplicationReasons(
        cohort: Institute.Source.Workspace.Cohort,
        policy: ContinuousIntegration.Source.Policy
    ) -> [SourceDomain.Reason] {
        let admitted = Swift.Set(cohort.admitted.map(\.identity))
        let controls = Swift.Set(
            cohort.controls.compactMap { row -> Swift.String? in
                guard case .control(let control) = row.role else { return nil }
                return control.rawValue
            }
        )
        var reasons: [SourceDomain.Reason] = []
        for identity in policy.commitment.repositories where !admitted.contains(identity) {
            reasons.append(.init(code: "self-application-repository", detail: identity))
        }
        for control in policy.commitment.controls where !controls.contains(control) {
            reasons.append(.init(code: "self-application-control", detail: control))
        }
        let declaredRules = admitted.filter {
            $0.split(separator: "/").last?.hasSuffix(
                policy.commitment.rule.suffix
            ) == true
        }
        if declaredRules.isEmpty {
            reasons.append(
                .init(
                    code: "self-application-rule-family",
                    detail: policy.commitment.rule.suffix
                )
            )
        }
        return reasons
    }

    private static func unmeasuredReport(
        scope: SourceDomain.Report.Scope,
        reason: SourceDomain.Reason
    ) -> SourceDomain.Report {
        .init(
            scope: scope,
            profile: .init("stale"),
            commitment: .init(subjects: [], engines: [], requirements: [], predicates: []),
            subjects: [],
            references: [reason],
            measurements: [],
            artifactEvidence: []
        )
    }
}
