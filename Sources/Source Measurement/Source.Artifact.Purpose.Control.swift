extension Source.Artifact.Purpose {
  public struct Control: Hashable, Sendable, JSON.Serializable {
    public let identity: Swift.String
    public let predicate: Source.Rule.ID
    public let expectation: Expectation

    public init(
      identity: Swift.String,
      predicate: Source.Rule.ID,
      expectation: Expectation
    ) {
      self.identity = identity
      self.predicate = predicate
      self.expectation = expectation
    }

    public static func serialize(_ value: Self) -> JSON {
      [
        "identity": value.identity.json,
        "predicate": value.predicate.json,
        "expectation": value.expectation.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary,
        Set(object.keys) == ["identity", "predicate", "expectation"],
        let identity = object["identity"], let predicate = object["predicate"],
        let expectation = object["expectation"]
      else { throw .typeMismatch(expected: "source control", got: "other") }
      return try .init(
        identity: Swift.String(json: identity),
        predicate: Source.Rule.ID(json: predicate),
        expectation: Expectation(json: expectation)
      )
    }
  }
}
