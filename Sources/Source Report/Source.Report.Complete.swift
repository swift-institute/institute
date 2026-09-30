extension Source.Report {
  public struct Complete: Sendable {
    public let report: Source.Report

    public init(
      _ report: Source.Report,
      expected commitment: Source.Report.Commitment
    ) throws(Error) {
      guard report.scope == .workspace else { throw .partial }
      guard report.references.isEmpty else { throw .references }
      guard report.commitment == commitment else { throw .commitment }
      guard !commitment.subjects.isEmpty else { throw .subjects }
      let identities = commitment.subjects.map(\.identity)
      guard Set(identities).count == identities.count,
        report.subjects == commitment.subjects
      else { throw .subjects }
      let engineIDs = commitment.engines.map(\.id)
      guard Set(engineIDs).count == engineIDs.count,
        commitment.engines.allSatisfy({
          !$0.artifactKinds.isEmpty
            && Set($0.artifactKinds).count == $0.artifactKinds.count
        })
      else { throw .commitment }
      let ruleIDs = commitment.rules.map(\.id)
      let committedControls = commitment.rules.flatMap { rule in
        rule.controls.map { (identity: $0, rule: rule.id) }
      }
      let measuredRuleIDs = Set(commitment.requirements.flatMap(\.rules))
      guard Set(ruleIDs).count == ruleIDs.count,
        commitment.rules.allSatisfy({ rule in
          guard let engine = commitment.engines.first(where: { $0.id == rule.id.engine })
          else { return false }
          return engineIDs.contains(rule.id.engine)
            && Set(rule.controls).count == rule.controls.count
            && rule.controls.allSatisfy({ !$0.isEmpty })
            && (!measuredRuleIDs.contains(rule.id)
              || engine.controlPolicy == .transitionalExternal
              || !rule.controls.isEmpty)
        }),
        Set(committedControls.map(\.identity)).count == committedControls.count
      else { throw .commitment }
      let predicateIDs = commitment.predicates.map(\.id)
      guard Set(predicateIDs).count == predicateIDs.count,
        commitment.predicates.allSatisfy({
          !$0.artifactKinds.isEmpty
            && Set($0.artifactKinds).count == $0.artifactKinds.count
            && engineIDs.contains($0.id.engine)
            && ruleIDs.contains($0.id)
        })
      else { throw .commitment }
      let subjectIDs = Set(identities)
      let requirementKeys = commitment.requirements.map {
        "\($0.subject)\u{0}\($0.engine.token)"
      }
      guard Set(requirementKeys).count == requirementKeys.count else { throw .commitment }
      for requirement in commitment.requirements {
        guard subjectIDs.contains(requirement.subject),
          engineIDs.contains(requirement.engine),
          !requirement.artifacts.isEmpty,
          Set(requirement.artifacts).count == requirement.artifacts.count,
          !requirement.rules.isEmpty,
          Set(requirement.rules).count == requirement.rules.count,
          requirement.rules.allSatisfy({ $0.engine == requirement.engine }),
          requirement.rules.allSatisfy(ruleIDs.contains),
          let subject = commitment.subjects.first(where: {
            $0.identity == requirement.subject
          }),
          let engine = commitment.engines.first(where: { $0.id == requirement.engine }),
          requirement.artifacts.allSatisfy({ path in
            subject.artifacts.contains {
              $0.path == path && engine.artifactKinds.contains($0.kind)
            }
          })
        else { throw .commitment }
      }
      var predicateArtifactKeys: [Swift.String] = []
      for requirement in commitment.predicateRequirements {
        guard subjectIDs.contains(requirement.subject),
          !requirement.artifacts.isEmpty,
          Set(requirement.artifacts).count == requirement.artifacts.count,
          !requirement.predicates.isEmpty,
          Set(requirement.predicates).count == requirement.predicates.count,
          requirement.predicates.allSatisfy(predicateIDs.contains),
          let subject = commitment.subjects.first(where: {
            $0.identity == requirement.subject
          }),
          requirement.artifacts.allSatisfy({ path in
            guard let artifact = subject.artifacts.first(where: { $0.path == path }) else {
              return false
            }
            return requirement.predicates.allSatisfy { predicateID in
              commitment.predicates.contains {
                $0.id == predicateID && $0.artifactKinds.contains(artifact.kind)
              }
            }
          })
        else { throw .commitment }
        predicateArtifactKeys.append(
          contentsOf: requirement.artifacts.map {
            requirement.subject + "\u{0}" + $0
          }
        )
      }
      guard Set(predicateArtifactKeys).count == predicateArtifactKeys.count else {
        throw .commitment
      }
      let usedEngines = Set(commitment.requirements.map(\.engine))
        .union(commitment.predicates.map(\.id.engine))
      let usedRules = Set(commitment.requirements.flatMap(\.rules))
        .union(commitment.predicateRequirements.flatMap(\.predicates))
      guard usedEngines == Set(engineIDs), usedRules == Set(ruleIDs),
        Set(commitment.predicateRequirements.flatMap(\.predicates)) == Set(predicateIDs)
      else { throw .commitment }

      let artifactControls = commitment.subjects.flatMap { subject in
        subject.artifacts.compactMap {
          artifact
            -> (
              identity: Swift.String, rule: Source.Rule.ID, subject: Swift.String,
              path: Swift.String
            )? in
          guard case .control(let control) = artifact.purpose else { return nil }
          return (control.identity, control.predicate, subject.identity, artifact.path)
        }
      }
      guard Set(artifactControls.map(\.identity)).count == artifactControls.count,
        artifactControls.allSatisfy({ control in
          committedControls.contains {
            $0.identity == control.identity && $0.rule == control.rule
          }
        }),
        committedControls.filter({ !measuredRuleIDs.contains($0.rule) }).allSatisfy({
          control in
          artifactControls.contains {
            $0.identity == control.identity && $0.rule == control.rule
          }
        })
      else { throw .commitment }
      guard report.controlEvidence.count == committedControls.count,
        Set(report.controlEvidence.map(\.identity)).count == report.controlEvidence.count,
        report.controlEvidence.allSatisfy({ evidence in
          committedControls.contains {
            $0.identity == evidence.identity && $0.rule == evidence.rule
          }
        })
      else { throw .coverage("control evidence") }
      let transportedControls = report.measurements.flatMap(\.controls)
      guard
        report.controlEvidence.filter({ measuredRuleIDs.contains($0.rule) }).allSatisfy({
          expected in
          transportedControls.contains { Self.same($0, expected) }
        }),
        transportedControls.allSatisfy({ measured in
          report.controlEvidence.contains { Self.same(measured, $0) }
        }),
        report.measurements.allSatisfy({ measurement in
          Set(measurement.controls.map(\.identity)).count == measurement.controls.count
        })
      else { throw .coverage("transported control evidence") }
      for control in committedControls {
        let evidence = report.controlEvidence.filter {
          $0.identity == control.identity && $0.rule == control.rule
        }
        guard evidence.count == 1, let measured = evidence.first, measured.actualFindings >= 0
        else { throw .coverage(control.identity) }
        if let artifactControl = artifactControls.first(where: {
          $0.identity == control.identity && $0.rule == control.rule
        }) {
          guard
            let artifact = commitment.subjects
              .first(where: { $0.identity == artifactControl.subject })?
              .artifacts.first(where: { $0.path == artifactControl.path }),
            case .control(let declaration) = artifact.purpose,
            measured.expectation == declaration.expectation
          else { throw .coverage(control.identity) }
        }
        let expectedFindings: Swift.Int
        switch measured.expectation {
        case .clean:
          expectedFindings = 0
        case .findings(let count):
          guard count > 0 else { throw .commitment }
          expectedFindings = count
        }
        switch measured.verdict {
        case .clean:
          guard measured.actualFindings == expectedFindings else {
            throw .coverage(control.identity)
          }
        case .findings(let reasons):
          guard measured.actualFindings != expectedFindings, !reasons.isEmpty else {
            throw .coverage(control.identity)
          }
        case .unmeasured:
          throw .coverage(control.identity)
        }
      }

      for subject in commitment.subjects {
        let paths = subject.artifacts.map(\.path)
        guard !paths.isEmpty, Set(paths).count == paths.count,
          subject.artifacts.allSatisfy({ !$0.digest.hex.isEmpty })
        else {
          throw .artifacts(subject.identity)
        }
        for artifact in subject.artifacts {
          if case .generatedPolicy = artifact.purpose,
            case .authored = artifact.provenance
          {
            throw .artifacts(subject.identity)
          }
          if case .control(let control) = artifact.purpose,
            control.identity.isEmpty
          {
            throw .artifacts(subject.identity)
          }
          guard case .generated(let binding) = artifact.provenance else { continue }
          guard !binding.owner.identity.isEmpty,
            subjectIDs.contains(binding.owner.identity),
            !binding.input.isEmpty,
            !binding.revision.isEmpty,
            !binding.digest.isEmpty
          else { throw .artifacts(subject.identity) }
        }
        let measurements = report.measurements.filter {
          $0.subject.identity == subject.identity
        }
        let requirements = commitment.requirements.filter {
          $0.subject == subject.identity
        }
        for requirement in requirements {
          let artifacts = subject.artifacts.filter {
            requirement.artifacts.contains($0.path)
          }
          let matching = measurements.filter { $0.engine == requirement.engine }
          guard matching.count == 1, let measurement = matching.first else {
            throw .engines(subject.identity)
          }
          guard measurement.subject == subject,
            measurement.files
              == Self.absolute(
                artifacts.map(\.path),
                under: subject.root
              ),
            Set(measurement.activeRules) == Set(requirement.rules),
            measurement.activeRules.count == requirement.rules.count
          else { throw .coverage(subject.identity) }
          try Self.validate(measurement)
        }
        let requiredEngines = Set(requirements.map(\.engine))
        guard Set(measurements.map(\.engine)) == requiredEngines else {
          throw .engines(subject.identity)
        }

        for artifact in subject.artifacts {
          let engineCoverage = requirements.contains {
            $0.artifacts.contains(artifact.path)
          }
          let controlCoverage: Swift.Bool
          if case .control(let control) = artifact.purpose {
            controlCoverage = report.controlEvidence.contains {
              $0.identity == control.identity && $0.rule == control.predicate
            }
          } else {
            controlCoverage = false
          }
          let requiredPredicateIDs = commitment.predicateRequirements
            .filter {
              $0.subject == subject.identity
                && $0.artifacts.contains(artifact.path)
            }
            .flatMap(\.predicates)
          guard engineCoverage || controlCoverage || !requiredPredicateIDs.isEmpty else {
            throw .artifacts(subject.identity)
          }
          for predicate in requiredPredicateIDs {
            let evidence = report.artifactEvidence.filter {
              $0.subject == subject.identity
                && $0.artifact == artifact
                && $0.predicate == predicate
            }
            guard evidence.count == 1, let measured = evidence.first else {
              throw .artifacts(subject.identity)
            }
            if case .unmeasured = measured.verdict {
              throw .artifacts(subject.identity)
            }
            switch measured.verdict {
            case .clean:
              guard measured.actual == measured.expected else {
                throw .artifacts(subject.identity)
              }
            case .findings:
              guard measured.actual != measured.expected else {
                throw .artifacts(subject.identity)
              }
            case .unmeasured:
              break
            }
            if case .findings(let reasons) = measured.verdict, reasons.isEmpty {
              throw .artifacts(subject.identity)
            }
          }
        }
      }
      guard report.measurements.count == commitment.requirements.count else {
        throw .engines("unexpected measurement")
      }
      let expectedEvidence = commitment.subjects.flatMap { subject in
        subject.artifacts.flatMap { artifact in
          commitment.predicateRequirements
            .filter {
              $0.subject == subject.identity
                && $0.artifacts.contains(artifact.path)
            }
            .flatMap(\.predicates)
            .map { (subject.identity, artifact, $0) }
        }
      }
      guard report.artifactEvidence.count == expectedEvidence.count else {
        throw .artifacts("unexpected evidence")
      }
      self.report = report
    }
  }
}

extension Source.Report.Complete {
  private static func validate(_ measurement: Source.Measurement) throws(Error) {
    let files = measurement.files
    let rules = measurement.activeRules
    let observationKeys = measurement.observations.map {
      Self.key(file: $0.file, rule: $0.rule)
    }
    guard Set(files).count == files.count,
      Set(rules).count == rules.count,
      rules.allSatisfy({ $0.engine == measurement.engine }),
      measurement.observations.count == files.count * rules.count,
      Set(observationKeys).count == observationKeys.count
    else { throw .coverage(measurement.subject.identity) }
    for file in files {
      for rule in rules {
        let observations = measurement.observations.filter {
          $0.file == file && $0.rule == rule
        }
        guard observations.count == 1, let observation = observations.first else {
          throw .coverage(measurement.subject.identity)
        }
        guard case .measured = observation.coverage else {
          throw .coverage(measurement.subject.identity)
        }
      }
    }
    let applicable = Set(
      measurement.observations.compactMap {
        $0.applicable ? $0.rule : nil
      }
    )
    guard applicable == Set(measurement.applicableRules),
      measurement.applicableRules.count == applicable.count,
      measurement.applicableRules.allSatisfy(rules.contains)
    else { throw .coverage(measurement.subject.identity) }
    let applicableKeys = Set(
      measurement.observations.compactMap {
        $0.applicable ? Self.key(file: $0.file, rule: $0.rule) : nil
      }
    )
    let suppressionIdentities = measurement.suppressions.map(Self.identity)
    for finding in measurement.suppressions {
      guard let path = finding.diagnostic.location.filePath,
        applicableKeys.contains(Self.key(file: path, rule: finding.rule)),
        !finding.diagnostic.message.isEmpty
      else { throw .coverage(measurement.subject.identity) }
    }
    guard Set(suppressionIdentities).count == suppressionIdentities.count else {
      throw .coverage(measurement.subject.identity)
    }
    let repairKeys = measurement.repairs.map {
      Self.key(file: $0.file, rule: $0.rule)
    }
    for repair in measurement.repairs {
      guard applicableKeys.contains(Self.key(file: repair.file, rule: repair.rule)) else {
        throw .coverage(measurement.subject.identity)
      }
    }
    guard Set(repairKeys).count == repairKeys.count else {
      throw .coverage(measurement.subject.identity)
    }
    switch measurement.verdict {
    case .clean:
      guard
        Set(repairKeys)
          == Set(
            measurement.suppressions.compactMap { finding in
              finding.diagnostic.location.filePath.map { path in
                Self.key(file: path, rule: finding.rule)
              }
            }
          )
      else { throw .coverage(measurement.subject.identity) }
    case .findings(let findings):
      let findingIdentities = findings.map(Self.identity)
      guard !findings.isEmpty,
        Set(findingIdentities).count == findingIdentities.count,
        findings.allSatisfy({ finding in
          guard let path = finding.diagnostic.location.filePath else { return false }
          return applicableKeys.contains(Self.key(file: path, rule: finding.rule))
            && !finding.diagnostic.message.isEmpty
        }),
        Set(repairKeys)
          == Set(
            (findings + measurement.suppressions).compactMap { finding in
              finding.diagnostic.location.filePath.map {
                Self.key(file: $0, rule: finding.rule)
              }
            }
          )
      else { throw .coverage(measurement.subject.identity) }
    case .unmeasured(let reasons):
      guard !reasons.isEmpty,
        reasons.allSatisfy({ !$0.code.isEmpty && !$0.detail.isEmpty })
      else { throw .coverage(measurement.subject.identity) }
      throw .coverage(measurement.subject.identity)
    case .notRequested:
      throw .coverage(measurement.subject.identity)
    }
  }

  private static func key(file: Swift.String, rule: Source.Rule.ID) -> Swift.String {
    file + "\u{0}" + rule.engine.token + "\u{0}" + rule.token
  }

  private static func identity(_ finding: Source.Finding) -> Swift.String {
    let location = finding.diagnostic.location
    return [
      finding.rule.engine.token,
      finding.rule.token,
      location.filePath ?? location.fileID,
      location.line.description,
      location.column.description,
      finding.diagnostic.identifier,
      finding.diagnostic.message,
    ].joined(separator: "\u{0}")
  }

  private static func same(
    _ lhs: Source.Rule.Control.Evidence,
    _ rhs: Source.Rule.Control.Evidence
  ) -> Swift.Bool {
    lhs.identity == rhs.identity
      && lhs.rule == rhs.rule
      && lhs.expectation == rhs.expectation
      && lhs.actualFindings == rhs.actualFindings
      && same(lhs.verdict, rhs.verdict)
  }

  private static func same(
    _ lhs: Source.Artifact.Verdict,
    _ rhs: Source.Artifact.Verdict
  ) -> Swift.Bool {
    switch (lhs, rhs) {
    case (.clean, .clean):
      true
    case (.findings(let left), .findings(let right)):
      left == right
    case (.unmeasured(let left), .unmeasured(let right)):
      left == right
    default:
      false
    }
  }

  private static func absolute(
    _ paths: [Swift.String],
    under root: Swift.String
  ) -> [Swift.String] {
    paths.map { path in
      if path.hasPrefix("/") { return path }
      return root.hasSuffix("/") ? root + path : root + "/" + path
    }.sorted()
  }
}
