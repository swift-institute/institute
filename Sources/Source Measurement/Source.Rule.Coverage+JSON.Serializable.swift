extension Source.Rule.Coverage: JSON.Serializable {
  public static func serialize(_ value: Self) -> JSON {
    switch value {
    case .measured: return ["status": "measured"]
    case .unmeasured(let reason):
      return ["status": "unmeasured", "reason": reason.json]
    }
  }

  public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
    guard let object = json.dictionary, let status = object["status"] else {
      throw .typeMismatch(expected: "coverage object", got: "other")
    }
    switch try Swift.String(json: status) {
    case "measured":
      guard Set(object.keys) == ["status"] else {
        throw .typeMismatch(expected: "measured coverage keys", got: "foreign keys")
      }
      return .measured
    case "unmeasured":
      guard Set(object.keys) == ["status", "reason"] else {
        throw .typeMismatch(expected: "unmeasured coverage keys", got: "foreign keys")
      }
      guard let reason = object["reason"] else { throw .missingKey("reason") }
      return try .unmeasured(Source.Reason(json: reason))
    default: throw .typeMismatch(expected: "coverage status", got: "unknown")
    }
  }
}
