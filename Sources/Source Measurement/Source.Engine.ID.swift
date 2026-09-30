extension Source.Engine {
  public struct ID: Hashable, Sendable, JSON.Serializable {
    public let token: Swift.String

    public init(_ token: Swift.String) {
      self.token = token
    }

    public static func serialize(_ value: Self) -> JSON { value.token.json }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      Self(try Swift.String(json: json))
    }
  }
}
