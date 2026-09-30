extension Source {
  public struct Reason: Swift.Error, Hashable, Sendable, JSON.Serializable {
    public let code: Swift.String
    public let detail: Swift.String

    public init(code: Swift.String, detail: Swift.String) {
      self.code = code
      self.detail = detail
    }

    public static func serialize(_ value: Self) -> JSON {
      ["code": value.code.json, "detail": value.detail.json]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      guard Set(object.keys) == ["code", "detail"] else {
        throw .typeMismatch(expected: "source reason keys", got: "foreign keys")
      }
      guard let code = object["code"] else { throw .missingKey("code") }
      guard let detail = object["detail"] else { throw .missingKey("detail") }
      return try Self(code: Swift.String(json: code), detail: Swift.String(json: detail))
    }
  }
}
