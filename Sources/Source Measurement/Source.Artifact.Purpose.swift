extension Source.Artifact {
  public enum Purpose: Hashable, Sendable, JSON.Serializable {
    case governedSource
    case generatedPolicy
    case control(Control)

    public static func serialize(_ value: Self) -> JSON {
      switch value {
      case .governedSource:
        ["role": "governed-source".json]
      case .generatedPolicy:
        ["role": "generated-policy".json]
      case .control(let control):
        ["role": "control".json, "control": control.json]
      }
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary, let role = object["role"] else {
        throw .typeMismatch(expected: "artifact purpose", got: "other")
      }
      switch try Swift.String(json: role) {
      case "governed-source":
        guard Set(object.keys) == ["role"] else {
          throw .typeMismatch(expected: "governed source purpose", got: "foreign keys")
        }
        return .governedSource
      case "generated-policy":
        guard Set(object.keys) == ["role"] else {
          throw .typeMismatch(expected: "generated policy purpose", got: "foreign keys")
        }
        return .generatedPolicy
      case "control":
        guard Set(object.keys) == ["role", "control"], let control = object["control"] else {
          throw .typeMismatch(expected: "control purpose", got: "foreign keys")
        }
        return try .control(Control(json: control))
      default:
        throw .typeMismatch(expected: "artifact purpose role", got: "unknown")
      }
    }
  }
}
