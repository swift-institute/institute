extension Source.Repair.Evidence {
  public struct ID: Hashable, Sendable {
    public let file: Swift.String
    public let rule: Source.Rule.ID

    public init(file: Swift.String, rule: Source.Rule.ID) {
      self.file = file
      self.rule = rule
    }
  }
}

extension Source.Repair.Evidence {
  public var id: ID { .init(file: file, rule: rule) }
}
