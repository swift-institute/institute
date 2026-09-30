extension Source {
  public struct Measurement: Sendable {
    public let engine: Engine.ID
    public let subject: Subject
    public let activeRules: [Rule.ID]
    public let applicableRules: [Rule.ID]
    public let files: [Swift.String]
    public let observations: [Rule.Observation]
    public let suppressions: [Finding]
    public let repairs: [Repair.Evidence]
    public let controls: [Rule.Control.Evidence]
    public let verdict: Verdict

    public init(
      engine: Engine.ID,
      subject: Subject,
      activeRules: [Rule.ID],
      applicableRules: [Rule.ID],
      files: [Swift.String],
      observations: [Rule.Observation] = [],
      suppressions: [Finding] = [],
      repairs: [Repair.Evidence] = [],
      controls: [Rule.Control.Evidence] = [],
      verdict: Verdict
    ) {
      self.engine = engine
      self.subject = subject
      self.activeRules = activeRules
      self.applicableRules = applicableRules
      self.files = files.sorted()
      self.observations = observations.sorted {
        ($0.file, $0.rule.token) < ($1.file, $1.rule.token)
      }
      self.suppressions = suppressions.sorted {
        ($0.diagnostic.location.fileID, $0.diagnostic.location.line, $0.rule.token)
          < ($1.diagnostic.location.fileID, $1.diagnostic.location.line, $1.rule.token)
      }
      self.repairs = repairs.sorted {
        ($0.file, $0.rule.token) < ($1.file, $1.rule.token)
      }
      self.controls = controls.sorted {
        ($0.rule.engine.token, $0.rule.token, $0.identity)
          < ($1.rule.engine.token, $1.rule.token, $1.identity)
      }
      self.verdict = verdict
    }
  }
}
