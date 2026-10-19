extension Source.Artifact {
    public enum Provenance: Hashable, Sendable, JSON.Serializable {
        case authored
        case generated(Generated)

        public static func serialize(_ value: Self) -> JSON {
            switch value {
            case .authored:
                ["status": "authored".json]
            case .generated(let binding):
                ["status": "generated".json, "binding": binding.json]
            }
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let status = object["status"] else { throw .missingKey("status") }
            switch try Swift.String(json: status) {
            case "authored":
                guard Set(object.keys) == ["status"] else {
                    throw .typeMismatch(expected: "authored provenance", got: "foreign keys")
                }
                return .authored
            case "generated":
                guard Set(object.keys) == ["status", "binding"],
                    let binding = object["binding"]
                else {
                    throw .typeMismatch(expected: "generated provenance", got: "foreign keys")
                }
                return try .generated(Generated(json: binding))
            default:
                throw .typeMismatch(expected: "authored or generated", got: "other status")
            }
        }
    }
}
