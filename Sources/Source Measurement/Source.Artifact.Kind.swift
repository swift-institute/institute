extension Source.Artifact {
    public enum Kind: Swift.String, Hashable, Sendable, JSON.Serializable {
        case swift
        case configuration

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let kind = Self(rawValue: value) else {
                throw .typeMismatch(expected: "swift or configuration", got: value)
            }
            return kind
        }
    }
}
