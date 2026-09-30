extension Source.Repair {
  public struct Selection: Sendable {
    public let automaticRules: Swift.Set<Source.Rule.ID>?

    public init(automaticRules: Swift.Set<Source.Rule.ID>?) {
      self.automaticRules = automaticRules
    }
  }
}
