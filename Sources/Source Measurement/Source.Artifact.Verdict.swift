extension Source.Artifact {
  public enum Verdict: Sendable, JSON.Serializable {
    case clean
    case findings([Source.Reason])
    case unmeasured([Source.Reason])

    public static func serialize(_ value: Self) -> JSON {
      switch value {
      case .clean:
        ["status": "clean".json]
      case .findings(let reasons):
        ["status": "findings".json, "reasons": reasons.json]
      case .unmeasured(let reasons):
        ["status": "unmeasured".json, "reasons": reasons.json]
      }
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      guard let status = object["status"] else { throw .missingKey("status") }
      switch try Swift.String(json: status) {
      case "clean":
        guard Set(object.keys) == ["status"] else {
          throw .typeMismatch(
            expected: "clean artifact verdict keys",
            got: "foreign keys"
          )
        }
        return .clean
      case "findings":
        guard Set(object.keys) == ["status", "reasons"] else {
          throw .typeMismatch(expected: "artifact findings keys", got: "foreign keys")
        }
        guard let reasons = object["reasons"] else { throw .missingKey("reasons") }
        let decoded = try [Source.Reason](json: reasons)
        guard !decoded.isEmpty else {
          throw .typeMismatch(expected: "nonempty reasons", got: "empty")
        }
        return .findings(decoded)
      case "unmeasured":
        guard Set(object.keys) == ["status", "reasons"] else {
          throw .typeMismatch(expected: "artifact unmeasured keys", got: "foreign keys")
        }
        guard let reasons = object["reasons"] else { throw .missingKey("reasons") }
        let decoded = try [Source.Reason](json: reasons)
        guard !decoded.isEmpty else {
          throw .typeMismatch(expected: "nonempty reasons", got: "empty")
        }
        return .unmeasured(decoded)
      default:
        throw .typeMismatch(expected: "artifact verdict", got: "unknown status")
      }
    }
  }
}
