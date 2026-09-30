extension Source.Repair.Operation: JSON.Serializable {
  public static func serialize(_ value: Self) -> JSON {
    switch value {
    case .rewrite(let path, let expected, let replacement):
      [
        "kind": "rewrite".json,
        "path": path.json,
        "expected": expected.json,
        "replacement": replacement.map(Swift.Int.init).json,
      ]
    case .create(let path, let contents):
      [
        "kind": "create".json,
        "path": path.json,
        "contents": contents.map(Swift.Int.init).json,
      ]
    case .move(let from, let to, let expected):
      [
        "kind": "move".json,
        "from": from.json,
        "to": to.json,
        "expected": expected.json,
      ]
    case .delete(let path, let expected):
      ["kind": "delete".json, "path": path.json, "expected": expected.json]
    }
  }

  public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
    guard let object = json.dictionary else {
      throw .typeMismatch(expected: "object", got: "non-object")
    }
    func required(_ key: Swift.String) throws(JSON.Error) -> JSON {
      guard let value = object[key] else { throw .missingKey(key) }
      return value
    }
    func bytes(_ key: Swift.String) throws(JSON.Error) -> [UInt8] {
      let integers = try [Swift.Int](json: required(key))
      var bytes: [UInt8] = []
      bytes.reserveCapacity(integers.count)
      for integer in integers {
        guard let byte = UInt8(exactly: integer) else {
          throw .typeMismatch(expected: "byte", got: "integer out of range")
        }
        bytes.append(byte)
      }
      return bytes
    }
    switch try Swift.String(json: required("kind")) {
    case "rewrite":
      guard Set(object.keys) == ["kind", "path", "expected", "replacement"] else {
        throw .typeMismatch(expected: "rewrite operation keys", got: "foreign keys")
      }
      return try .rewrite(
        path: Swift.String(json: required("path")),
        expected: Swift.String(json: required("expected")),
        replacement: bytes("replacement")
      )
    case "create":
      guard Set(object.keys) == ["kind", "path", "contents"] else {
        throw .typeMismatch(expected: "create operation keys", got: "foreign keys")
      }
      return try .create(
        path: Swift.String(json: required("path")),
        contents: bytes("contents")
      )
    case "move":
      guard Set(object.keys) == ["kind", "from", "to", "expected"] else {
        throw .typeMismatch(expected: "move operation keys", got: "foreign keys")
      }
      return try .move(
        from: Swift.String(json: required("from")),
        to: Swift.String(json: required("to")),
        expected: Swift.String(json: required("expected"))
      )
    case "delete":
      guard Set(object.keys) == ["kind", "path", "expected"] else {
        throw .typeMismatch(expected: "delete operation keys", got: "foreign keys")
      }
      return try .delete(
        path: Swift.String(json: required("path")),
        expected: Swift.String(json: required("expected"))
      )
    default:
      throw .typeMismatch(expected: "repair operation", got: "unknown")
    }
  }
}
