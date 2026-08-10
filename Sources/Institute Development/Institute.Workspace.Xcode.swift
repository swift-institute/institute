public import Institute_Model
public import JSON

extension Institute.Workspace {
  public struct Xcode: Swift.Equatable, Swift.Sendable, JSON.Serializable {
    public let name: Swift.String
    public let members: [Swift.String]

    public init(name: Swift.String, members: [Swift.String]) {
      self.name = name
      self.members = members
    }

    public static func serialize(_ value: Self) -> JSON {
      ["name": value.name.json, "members": value.members.json]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      let expected: Set<Swift.String> = ["name", "members"]
      guard Set(object.keys) == expected else {
        throw .typeMismatch(
          expected: "xcode keys name and members", got: object.keys.sorted().joined(separator: ", ")
        )
      }
      return try Self(
        name: Swift.String(json: object["name"]!), members: [Swift.String](json: object["members"]!)
      )
    }
  }
}
