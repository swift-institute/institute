extension Source.Report {
  public enum Status: Swift.Int32, Sendable {
    case clean = 0
    case findings = 1
    case unmeasured = 2

    public init(
      _ report: Source.Report,
      expected commitment: Source.Report.Commitment
    ) {
      guard (try? Source.Report.Complete(report, expected: commitment)) != nil else {
        self = .unmeasured
        return
      }
      let engineFindings = report.measurements.contains { measurement in
        if case .findings = measurement.verdict { true } else { false }
      }
      let artifactFindings = report.artifactEvidence.contains { evidence in
        if case .findings = evidence.verdict { true } else { false }
      }
      let controlFindings = report.controlEvidence.contains { evidence in
        if case .findings = evidence.verdict { true } else { false }
      }
      self = engineFindings || artifactFindings || controlFindings ? .findings : .clean
    }

    public var code: Swift.Int32 { rawValue }
  }
}
