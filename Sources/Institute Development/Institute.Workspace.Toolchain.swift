public import Institute_Model
public import JSON

extension Institute.Workspace {
  public struct Toolchain: Swift.Equatable, Swift.Sendable, JSON.Serializable {
    public let swift: Swift.String
    public let xcode: Swift.String

    public init(swift: Swift.String, xcode: Swift.String) {
      self.swift = swift
      self.xcode = xcode
    }

    public static func serialize(_ value: Self) -> JSON {
      ["swift": value.swift.json, "xcode": value.xcode.json]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      let expected: Set<Swift.String> = ["swift", "xcode"]
      guard Set(object.keys) == expected else {
        throw .typeMismatch(
          expected: "toolchain keys swift and xcode",
          got: object.keys.sorted().joined(separator: ", "))
      }
      return try Self(
        swift: Swift.String(json: object["swift"]!), xcode: Swift.String(json: object["xcode"]!))
    }
  }
}
