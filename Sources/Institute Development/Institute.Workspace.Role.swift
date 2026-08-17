public import Institute_Model
public import JSON

extension Institute.Workspace {
  public enum Role: Swift.String, Swift.CaseIterable, Swift.Sendable, JSON.Serializable {
    case application
    case domain
    case dependency
    case tooling

    public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      let token = try Swift.String(json: json)
      guard let value = Self(rawValue: token) else {
        throw .typeMismatch(expected: "workspace repository role", got: token)
      }
      return value
    }
  }
}
