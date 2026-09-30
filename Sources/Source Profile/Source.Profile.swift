extension Source {
  public struct Profile: Equatable, Sendable, JSON.Serializable {
    public static let schema = 2

    public let revision: Swift.String
    public let engines: [Engine]

    public init(revision: Swift.String, engines: [Engine]) {
      self.revision = revision
      self.engines = engines.sorted { $0.id.token < $1.id.token }
    }

    public var digest: Digest {
      let bytes = jsonString(sortKeys: true).utf8.map(Byte.init)
      return Digest(FIPS_180_4.SHA256.digest(bytes).hex)
    }

    public static func serialize(_ value: Self) -> JSON {
      [
        "schema": schema.json,
        "revision": value.revision.json,
        "engines": value.engines.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      guard Set(object.keys) == ["schema", "revision", "engines"] else {
        throw .typeMismatch(expected: "source profile keys", got: "foreign keys")
      }
      guard let schema = object["schema"], try Swift.Int(json: schema) == Self.schema else {
        throw .typeMismatch(expected: "source profile schema 2", got: "other schema")
      }
      guard let revision = object["revision"] else { throw .missingKey("revision") }
      guard let engines = object["engines"] else { throw .missingKey("engines") }
      return try Self(
        revision: Swift.String(json: revision),
        engines: [Engine](json: engines)
      )
    }
  }
}
