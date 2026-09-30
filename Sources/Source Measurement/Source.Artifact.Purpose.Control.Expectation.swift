extension Source.Artifact.Purpose.Control {
  public enum Expectation: Hashable, Sendable, JSON.Serializable {
    case clean
    case findings(Swift.Int)

    public static func serialize(_ value: Self) -> JSON {
      switch value {
      case .clean:
        ["status": "clean".json]
      case .findings(let count):
        ["status": "findings".json, "count": count.json]
      }
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary, let status = object["status"] else {
        throw .typeMismatch(expected: "control expectation", got: "other")
      }
      switch try Swift.String(json: status) {
      case "clean":
        guard Set(object.keys) == ["status"] else {
          throw .typeMismatch(expected: "clean control expectation", got: "foreign keys")
        }
        return .clean
      case "findings":
        guard Set(object.keys) == ["status", "count"], let count = object["count"] else {
          throw .typeMismatch(expected: "finding control expectation", got: "foreign keys")
        }
        return try .findings(Swift.Int(json: count))
      default:
        throw .typeMismatch(expected: "control expectation status", got: "unknown")
      }
    }
  }
}
