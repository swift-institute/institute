extension Source {
  public struct Finding: Hashable, Sendable {
    public let rule: Rule.ID
    public let diagnostic: Diagnostic.Record
    public let repair: Repair.Capability

    public init(
      rule: Rule.ID,
      diagnostic: Diagnostic.Record,
      repair: Repair.Capability
    ) {
      self.rule = rule
      self.diagnostic = diagnostic
      self.repair = repair
    }
  }
}
