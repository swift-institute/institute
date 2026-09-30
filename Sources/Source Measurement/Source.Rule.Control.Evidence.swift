extension Source.Rule.Control {
  public struct Evidence: Sendable, JSON.Serializable {
    public let identity: Swift.String
    public let rule: Source.Rule.ID
    public let expectation: Source.Artifact.Purpose.Control.Expectation
    public let actualFindings: Swift.Int
    public let verdict: Source.Artifact.Verdict

    public init(
      identity: Swift.String,
      rule: Source.Rule.ID,
      expectation: Source.Artifact.Purpose.Control.Expectation,
      actualFindings: Swift.Int,
      verdict: Source.Artifact.Verdict
    ) {
      self.identity = identity
      self.rule = rule
      self.expectation = expectation
      self.actualFindings = actualFindings
      self.verdict = verdict
    }

    public static func serialize(_ value: Self) -> JSON {
      [
        "identity": value.identity.json,
        "rule": value.rule.json,
        "expectation": value.expectation.json,
        "actualFindings": value.actualFindings.json,
        "verdict": value.verdict.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary,
        Set(object.keys)
          == ["identity", "rule", "expectation", "actualFindings", "verdict"],
        let identity = object["identity"], let rule = object["rule"],
        let expectation = object["expectation"],
        let actualFindings = object["actualFindings"], let verdict = object["verdict"]
      else { throw .typeMismatch(expected: "control evidence", got: "other") }
      return try .init(
        identity: Swift.String(json: identity),
        rule: Source.Rule.ID(json: rule),
        expectation: Source.Artifact.Purpose.Control.Expectation(json: expectation),
        actualFindings: Swift.Int(json: actualFindings),
        verdict: Source.Artifact.Verdict(json: verdict)
      )
    }
  }
}
