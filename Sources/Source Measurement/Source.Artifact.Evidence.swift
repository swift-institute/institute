extension Source.Artifact {
  public struct Evidence: Sendable {
    public let subject: Swift.String
    public let artifact: Source.Artifact
    public let predicate: Source.Rule.ID
    public let actual: Source.Artifact.Identity
    public let expected: Source.Artifact.Identity
    public let verdict: Source.Artifact.Verdict

    public init(
      subject: Swift.String,
      artifact: Source.Artifact,
      predicate: Source.Rule.ID,
      actual: Source.Artifact.Identity,
      expected: Source.Artifact.Identity,
      verdict: Source.Artifact.Verdict
    ) {
      self.subject = subject
      self.artifact = artifact
      self.predicate = predicate
      self.actual = actual
      self.expected = expected
      self.verdict = verdict
    }
  }
}

extension Source.Artifact.Evidence: JSON.Serializable {
  public static func serialize(_ value: Self) -> JSON {
    [
      "subject": value.subject.json,
      "artifact": value.artifact.json,
      "predicate": value.predicate.json,
      "actual": value.actual.json,
      "expected": value.expected.json,
      "verdict": value.verdict.json,
    ]
  }

  public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
    guard let object = json.dictionary else {
      throw .typeMismatch(expected: "object", got: "non-object")
    }
    guard
      Set(object.keys)
        == ["subject", "artifact", "predicate", "actual", "expected", "verdict"]
    else {
      throw .typeMismatch(expected: "artifact evidence keys", got: "foreign keys")
    }
    func required(_ key: Swift.String) throws(JSON.Error) -> JSON {
      guard let value = object[key] else { throw .missingKey(key) }
      return value
    }
    return try Self(
      subject: Swift.String(json: required("subject")),
      artifact: Source.Artifact(json: required("artifact")),
      predicate: Source.Rule.ID(json: required("predicate")),
      actual: Source.Artifact.Identity(json: required("actual")),
      expected: Source.Artifact.Identity(json: required("expected")),
      verdict: Source.Artifact.Verdict(json: required("verdict"))
    )
  }
}
