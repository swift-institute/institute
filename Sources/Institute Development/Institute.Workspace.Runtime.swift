public import Institute_Model
public import JSON

extension Institute.Workspace {
  public struct Runtime: Swift.Equatable, Swift.Sendable, JSON.Serializable {
    public let compose: Swift.String

    public init(compose: Swift.String) { self.compose = compose }

    public static func serialize(_ value: Self) -> JSON { ["compose": value.compose.json] }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      guard Set(object.keys) == ["compose"] else {
        throw .typeMismatch(
          expected: "runtime key compose", got: object.keys.sorted().joined(separator: ", "))
      }
      return try Self(compose: Swift.String(json: object["compose"]!))
    }
  }
}
