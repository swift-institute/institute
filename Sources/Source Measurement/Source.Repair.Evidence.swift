extension Source.Repair {
  public struct Evidence: Hashable, Sendable {
    public let file: Swift.String
    public let rule: Source.Rule.ID
    public let disposition: Disposition

    public init(file: Swift.String, rule: Source.Rule.ID, disposition: Disposition) {
      self.file = file
      self.rule = rule
      self.disposition = disposition
    }
  }
}
