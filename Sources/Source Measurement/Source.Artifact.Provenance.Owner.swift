extension Source.Artifact.Provenance {
  public struct Owner: Hashable, Sendable {
    public let identity: Swift.String

    public init(_ identity: Swift.String) {
      self.identity = identity
    }
  }
}

extension Source.Artifact.Provenance.Owner: JSON.Serializable {
  public static func serialize(_ value: Self) -> JSON { value.identity.json }

  public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
    .init(try Swift.String(json: json))
  }
}
