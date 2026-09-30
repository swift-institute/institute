public import Async_Fanout
public import FIPS_180_4
public import Institute_Source_Policy
public import Institute_Model
internal import Institute_Source_Profile
public import Institute_Source_Workspace
public import Source_Execution
import Source_Linter
public import Source_Measurement
internal import Source_Profile
import Source_Repair
public import Source_Report
import Source_Swift_Format

extension Institute.Source.Application {
  public static func bundle(_ token: Swift.String) throws(Institute.Error)
    -> Institute.Source.Bundle
  {
    guard let bundle = Institute.Source.Bundle(rawValue: token) else {
      throw .configuration("invalid source bundle \(token)")
    }
    return bundle
  }

  public func measure(
    cohort: Institute.Source.Workspace.Cohort,
    selected: [Institute.Source.Workspace.Row]? = nil,
    engines: Set<Source_Measurement.Source.Engine.ID>? = nil,
    jobs: Swift.Int? = nil,
    references: [Source_Measurement.Source.Reason] = [],
    preparation: Institute.Source.Preparation
  ) async throws(Institute.Error) -> Source_Report.Source.Report {
    let rows = selected ?? cohort.measurable
    let scope: Source_Report.Source.Report.Scope =
      selected == nil && engines == nil ? .workspace : .partial
    let expectedBinding = Institute.Source.Preparation.Binding.workspace(
      digest: try Self.digest(file: cohort.workspace + "/contents.xcworkspacedata").hex
    )
    guard preparation.binding == expectedBinding else {
      return Self.unmeasuredReport(
        scope: scope,
        reason: .init(code: "stale-subject", detail: cohort.workspace)
      )
    }
    let owner = Institute.Source.Profile(policy: .current)
    var entries:
      [(bundle: Institute.Source.Bundle, subject: Source_Measurement.Source.Subject)] = []
    for row in rows {
      entries.append(
        (
          bundle: try owner.bundle(for: row),
          subject: try Institute.Source.Workspace.subject(for: row)
        )
      )
    }
    return try await measure(
      entries: entries,
      scope: scope,
      engines: engines,
      jobs: jobs,
      references: cohort.reasons
        + Self.selfApplicationReasons(cohort: cohort, policy: .current)
        + references,
      preparation: preparation
    )
  }

  public func measure(
    subject: Source_Measurement.Source.Subject,
    bundle: Institute.Source.Bundle,
    jobs: Swift.Int? = nil,
    preparation: Institute.Source.Preparation
  ) async throws(Institute.Error) -> Source_Report.Source.Report {
    guard preparation.binding == .package(subject.binding) else {
      return Self.unmeasuredReport(
        scope: .workspace,
        reason: .init(code: "stale-subject", detail: subject.identity)
      )
    }
    return try await measure(
      entries: [(bundle: bundle, subject: subject)],
      scope: .workspace,
      engines: nil,
      jobs: jobs,
      references: [],
      preparation: preparation
    )
  }

  private func measure(
    entries: [(bundle: Institute.Source.Bundle, subject: Source_Measurement.Source.Subject)],
    scope: Source_Report.Source.Report.Scope,
    engines: Set<Source_Measurement.Source.Engine.ID>?,
    jobs: Swift.Int?,
    references: [Source_Measurement.Source.Reason],
    preparation: Institute.Source.Preparation
  ) async throws(Institute.Error) -> Source_Report.Source.Report {
    let policy = Institute.Source.Policy.current
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
      Self.matches(
        file: preparation.swiftLintExecutable,
        digest: preparation.swiftLintTool
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
      ),
      Self.matches(
        file: "\(preparation.directory)/.swiftlint.yml",
        digest: policy.swiftLint.digest
      )
    else {
      return Self.unmeasuredReport(
        scope: scope,
        reason: .init(code: "stale-configuration", detail: ".swift-format")
      )
    }

    let execution: Source_Execution.Source.Execution
    do throws(Source_Execution.Source.Execution.Error) {
      execution = try .init(process: process)
    } catch {
      throw .configuration("cannot register source engines: \(error)")
    }
    var subjects = entries.map(\.subject)
    let configuration = try Self.configuration(policy: policy, preparation: preparation)
    subjects.append(configuration.subject)
    let owner = Institute.Source.Profile(policy: policy)
    var requirements: [Source_Report.Source.Report.Commitment.Requirement] = []
    for entry in entries {
      let bundle = entry.bundle
      let artifacts = entry.subject.artifacts.filter { $0.kind == .swift }.map(\.path)
      for engine in policy.requiredEngines where engines?.contains(engine) ?? true {
        let rules: [Source_Measurement.Source.Rule.ID]
        switch engine.token {
        case "swift-format":
          rules = [.init(engine: engine, token: "format")]
        case "swiftlint":
          rules = policy.swiftLintRules
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
    let measuredBySubject: [[Source_Measurement.Source.Measurement]] = await Async.Fanout(
      jobs: jobs ?? 1
    ).mapAsync(entries) { entry in
      let subject = entry.subject
      let bundle = entry.bundle
      let rules = Institute.Source.Profile(policy: policy).rules(for: bundle)
      let linterConfiguration =
        "\(preparation.directory)/\(bundle.rawValue)-source-linter-profile.json"
      let linterArtifact = policy.linter(bundle: bundle, rules: rules)
      guard preparation.verifiedProfiles.contains(bundle.rawValue) else {
        return policy.requiredEngines.map {
          .init(
            engine: $0,
            subject: subject,
            activeRules: [],
            applicableRules: [],
            files: subject.paths(of: .swift),
            verdict: .unmeasured([
              .init(code: "unverified-profile", detail: bundle.rawValue)
            ])
          )
        }
      }
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
        swiftLintExecutable: preparation.swiftLintExecutable,
        swiftLintTool: preparation.swiftLintTool,
        swiftLintConfigurationPath: "\(preparation.directory)/.swiftlint.yml",
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
      let measured = await execution.measure(subject, profile: profile, engines: engines)
      let current: Source_Measurement.Source.Subject
      do throws(Institute.Error) {
        current = try Institute.Source.Workspace.subject(
          identity: subject.identity,
          root: subject.root
        )
      } catch {
        return profile.engines.map {
          .init(
            engine: $0.id,
            subject: subject,
            activeRules: $0.rules,
            applicableRules: [],
            files: subject.paths(of: .swift),
            verdict: .unmeasured([
              .init(code: "source-changed", detail: "\(error)")
            ])
          )
        }
      }
      guard current == subject else {
        return profile.engines.map {
          .init(
            engine: $0.id,
            subject: subject,
            activeRules: $0.rules,
            applicableRules: [],
            files: subject.paths(of: .swift),
            verdict: .unmeasured([
              .init(code: "source-changed", detail: subject.identity)
            ])
          )
        }
      }
      return measured
    }
    let measurements = measuredBySubject.flatMap { $0 }
    var controlIdentities: Swift.Set<Swift.String> = []
    let controlEvidence = measurements.flatMap(\.controls).filter {
      controlIdentities.insert($0.identity).inserted
    }
    let profileBytes = preparation.profiles.keys.sorted()
      .compactMap { preparation.profiles[$0]?.hex }
      .joined(separator: ":").utf8.map(Byte.init(_:))
    let digest = Source_Profile.Source.Profile.Digest(FIPS_180_4.SHA256.digest(profileBytes).hex)
    return .init(
      scope: scope,
      profile: digest,
      commitment: .init(
        subjects: subjects,
        engines: policy.requiredEngines.map {
          let controlPolicy: Source_Report.Source.Report.Commitment.Engine.ControlPolicy =
            switch $0.token {
            case "swift-format", "swiftlint":
              .transitionalExternal
            default:
              .required
            }
          return .init(
            id: $0,
            artifactKinds: [.swift],
            controlPolicy: controlPolicy
          )
        } + [
          .init(id: policy.configuration.engine, artifactKinds: [.configuration])
        ],
        rules: Swift.Set(
          requirements.flatMap(\.rules) + [policy.configuration.predicate]
        ).map { rule in
          .init(
            id: rule,
            controls: controlEvidence.filter { $0.rule == rule }.map(\.identity)
          )
        },
        requirements: requirements,
        predicates: [
          .init(
            id: policy.configuration.predicate,
            artifactKinds: [.configuration]
          )
        ],
        predicateRequirements: [
          .init(
            subject: configuration.subject.identity,
            artifacts: configuration.subject.artifacts.map(\.path),
            predicates: [policy.configuration.predicate]
          )
        ]
      ),
      subjects: subjects,
      references: references,
      measurements: measurements,
      artifactEvidence: configuration.evidence,
      controlEvidence: controlEvidence
    )
  }

  private static func selfApplicationReasons(
    cohort: Institute.Source.Workspace.Cohort,
    policy: Institute.Source.Policy
  ) -> [Source_Measurement.Source.Reason] {
    let admitted = Swift.Set(cohort.admitted.map(\.identity))
    let controls = Swift.Set(
      cohort.controls.compactMap { row -> Swift.String? in
        guard case .control(let control) = row.role else { return nil }
        return control.rawValue
      }
    )
    var reasons: [Source_Measurement.Source.Reason] = []
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
    scope: Source_Report.Source.Report.Scope,
    reason: Source_Measurement.Source.Reason
  ) -> Source_Report.Source.Report {
    .init(
      scope: scope,
      profile: .init("stale"),
      commitment: .init(
        subjects: [],
        engines: [],
        rules: [],
        requirements: [],
        predicates: [],
        predicateRequirements: []
      ),
      subjects: [],
      references: [reason],
      measurements: [],
      artifactEvidence: [],
      controlEvidence: []
    )
  }
}
