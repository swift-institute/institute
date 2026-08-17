public import Institute_Model
public import JSON

extension Institute.Workspace {
  public struct Composition: Swift.Equatable, Swift.Hashable, Swift.Sendable, JSON.Serializable {
    public let consumer: Swift.String
    public let dependency: Swift.String

    public init(consumer: Swift.String, dependency: Swift.String) {
      self.consumer = consumer
      self.dependency = dependency
    }

    public static func serialize(_ value: Self) -> JSON {
      ["consumer": value.consumer.json, "dependency": value.dependency.json]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      let expected: Set<Swift.String> = ["consumer", "dependency"]
      guard Set(object.keys) == expected else {
        throw .typeMismatch(
          expected: "composition keys consumer and dependency",
          got: object.keys.sorted().joined(separator: ", "))
      }
      return try Self(
        consumer: Swift.String(json: object["consumer"]!),
        dependency: Swift.String(json: object["dependency"]!)
      )
    }
  }
}
