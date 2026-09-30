extension Source.Artifact.Provenance {
  public struct Generated: Hashable, Sendable {
    public let owner: Source.Artifact.Provenance.Owner
    public let input: Swift.String
    public let revision: Swift.String
    public let digest: Swift.String

    public init(
      owner: Source.Artifact.Provenance.Owner,
      input: Swift.String,
      revision: Swift.String,
      digest: Swift.String
    ) {
      self.owner = owner
      self.input = input
      self.revision = revision
      self.digest = digest
    }
  }
}

extension Source.Artifact.Provenance.Generated: JSON.Serializable {
  public static func serialize(_ value: Self) -> JSON {
    [
      "owner": value.owner.json,
      "input": value.input.json,
      "revision": value.revision.json,
      "digest": value.digest.json,
    ]
  }

  public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
    guard let object = json.dictionary,
      Set(object.keys) == ["owner", "input", "revision", "digest"],
      let owner = object["owner"], let input = object["input"],
      let revision = object["revision"], let digest = object["digest"]
    else { throw .typeMismatch(expected: "generated provenance", got: "other") }
    return try .init(
      owner: Source.Artifact.Provenance.Owner(json: owner),
      input: Swift.String(json: input),
      revision: Swift.String(json: revision),
      digest: Swift.String(json: digest)
    )
  }
}
