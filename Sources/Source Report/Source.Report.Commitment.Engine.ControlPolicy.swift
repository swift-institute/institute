extension Source.Report.Commitment.Engine {
  public enum ControlPolicy: Swift.String, Sendable, JSON.Serializable {
    case required
    case transitionalExternal = "transitional-external"

    public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      let token = try Swift.String(json: json)
      guard let value = Self(rawValue: token) else {
        throw .typeMismatch(expected: "engine control policy", got: token)
      }
      return value
    }
  }
}
