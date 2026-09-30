extension Source.Rule {
  public struct Observation: Hashable, Sendable {
    public let file: Swift.String
    public let rule: ID
    public let applicable: Swift.Bool
    public let coverage: Coverage

    public init(
      file: Swift.String,
      rule: ID,
      applicable: Swift.Bool,
      coverage: Coverage
    ) {
      self.file = file
      self.rule = rule
      self.applicable = applicable
      self.coverage = coverage
    }
  }
}
