extension Source {
  public struct Report: Sendable, JSON.Serializable {
    public static let schema = 10

    public let scope: Scope
    public let profile: Profile.Digest
    public let commitment: Commitment
    public let subjects: [Subject]
    public let references: [Reason]
    public let measurements: [Measurement]
    public let artifactEvidence: [Artifact.Evidence]
    public let controlEvidence: [Rule.Control.Evidence]

    public init(
      scope: Scope,
      profile: Profile.Digest,
      commitment: Commitment,
      subjects: [Subject],
      references: [Reason],
      measurements: [Measurement],
      artifactEvidence: [Artifact.Evidence],
      controlEvidence: [Rule.Control.Evidence]
    ) {
      self.scope = scope
      self.profile = profile
      self.commitment = commitment
      self.subjects = subjects.sorted { $0.identity < $1.identity }
      self.references = references.sorted { ($0.code, $0.detail) < ($1.code, $1.detail) }
      self.measurements = measurements.sorted {
        ($0.subject.identity, $0.engine.token) < ($1.subject.identity, $1.engine.token)
      }
      self.artifactEvidence = artifactEvidence.sorted {
        ($0.subject, $0.artifact.path, $0.predicate.engine.token, $0.predicate.token)
          < ($1.subject, $1.artifact.path, $1.predicate.engine.token, $1.predicate.token)
      }
      self.controlEvidence = controlEvidence.sorted {
        ($0.rule.engine.token, $0.rule.token, $0.identity)
          < ($1.rule.engine.token, $1.rule.token, $1.identity)
      }
    }

    public static func serialize(_ value: Self) -> JSON {
      [
        "schema": schema.json,
        "scope": value.scope.json,
        "profile": value.profile.json,
        "commitment": value.commitment.json,
        "subjects": value.subjects.json,
        "references": value.references.json,
        "measurements": value.measurements.json,
        "artifactEvidence": value.artifactEvidence.json,
        "controlEvidence": value.controlEvidence.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      let expected: Set<Swift.String> = [
        "schema", "scope", "profile", "commitment", "subjects", "references",
        "measurements", "artifactEvidence",
        "controlEvidence",
      ]
      guard Set(object.keys) == expected else {
        throw .typeMismatch(expected: "source report keys", got: "foreign keys")
      }
      func required(_ key: Swift.String) throws(JSON.Error) -> JSON {
        guard let value = object[key] else { throw .missingKey(key) }
        return value
      }
      guard try Swift.Int(json: required("schema")) == schema else {
        throw .typeMismatch(expected: "source report schema 10", got: "other schema")
      }
      return try Self(
        scope: Scope(json: required("scope")),
        profile: Profile.Digest(json: required("profile")),
        commitment: Commitment(json: required("commitment")),
        subjects: [Subject](json: required("subjects")),
        references: [Reason](json: required("references")),
        measurements: [Measurement](json: required("measurements")),
        artifactEvidence: [Artifact.Evidence](json: required("artifactEvidence")),
        controlEvidence: [Rule.Control.Evidence](json: required("controlEvidence"))
      )
    }
  }
}
