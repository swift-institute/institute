extension Source.Report.Commitment {
  public struct PredicateRequirement: Equatable, Sendable, JSON.Serializable {
    public let subject: Swift.String
    public let artifacts: [Swift.String]
    public let predicates: [Source.Rule.ID]

    public init(
      subject: Swift.String,
      artifacts: [Swift.String],
      predicates: [Source.Rule.ID]
    ) {
      self.subject = subject
      self.artifacts = artifacts.sorted()
      self.predicates = predicates.sorted {
        ($0.engine.token, $0.token) < ($1.engine.token, $1.token)
      }
    }

    public static func serialize(_ value: Self) -> JSON {
      [
        "subject": value.subject.json,
        "artifacts": value.artifacts.json,
        "predicates": value.predicates.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary,
        Set(object.keys) == ["subject", "artifacts", "predicates"],
        let subject = object["subject"], let artifacts = object["artifacts"],
        let predicates = object["predicates"]
      else { throw .typeMismatch(expected: "predicate requirement", got: "other") }
      return try .init(
        subject: Swift.String(json: subject),
        artifacts: [Swift.String](json: artifacts),
        predicates: [Source.Rule.ID](json: predicates)
      )
    }
  }
}
