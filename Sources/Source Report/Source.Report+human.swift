extension Source.Report {
  public var human: Swift.String {
    var lines = [
      "source profile \(profile.hex)",
      "scope: \(scope.rawValue)",
      "subjects: \(subjects.count)",
    ]
    for reason in references {
      lines.append("UNMEASURED reference \(reason.code): \(reason.detail)")
    }
    for measurement in measurements {
      switch measurement.verdict {
      case .clean:
        lines.append("CLEAN \(measurement.subject.identity) \(measurement.engine.token)")
      case .findings(let findings):
        lines.append(
          "FINDINGS \(measurement.subject.identity) \(measurement.engine.token) \(findings.count)"
        )
      case .unmeasured(let reasons):
        for reason in reasons {
          lines.append(
            "UNMEASURED \(measurement.subject.identity) \(measurement.engine.token) \(reason.code): \(reason.detail)"
          )
        }
      case .notRequested:
        lines.append(
          "NOT REQUESTED \(measurement.subject.identity) \(measurement.engine.token)"
        )
      }
    }
    for evidence in artifactEvidence {
      switch evidence.verdict {
      case .clean:
        lines.append(
          "CLEAN \(evidence.subject) \(evidence.predicate.engine.token):\(evidence.predicate.token) \(evidence.artifact.path)"
        )
      case .findings(let reasons):
        lines.append(
          "FINDINGS \(evidence.subject) \(evidence.predicate.engine.token):\(evidence.predicate.token) \(evidence.artifact.path) \(reasons.count)"
        )
      case .unmeasured(let reasons):
        for reason in reasons {
          lines.append(
            "UNMEASURED \(evidence.subject) \(evidence.predicate.engine.token):\(evidence.predicate.token) \(evidence.artifact.path) \(reason.code): \(reason.detail)"
          )
        }
      }
    }
    return lines.joined(separator: "\n") + "\n"
  }
}
