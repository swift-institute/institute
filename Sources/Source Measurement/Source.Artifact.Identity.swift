extension Source.Artifact {
  public struct Identity: Hashable, Sendable, JSON.Serializable {
    public let digest: Source.Artifact.Digest
    public let schema: Source.Artifact.Schema

    public init(digest: Source.Artifact.Digest, schema: Source.Artifact.Schema) {
      self.digest = digest
      self.schema = schema
    }
  }
}

extension Source.Artifact.Identity {
  public static func serialize(_ value: Self) -> JSON {
    ["digest": value.digest.json, "schema": value.schema.json]
  }

  public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
    guard let object = json.dictionary,
      Set(object.keys) == ["digest", "schema"],
      let digest = object["digest"], let schema = object["schema"]
    else { throw .typeMismatch(expected: "artifact identity", got: "other") }
    return try .init(
      digest: Source.Artifact.Digest(json: digest),
      schema: Source.Artifact.Schema(json: schema)
    )
  }
}
