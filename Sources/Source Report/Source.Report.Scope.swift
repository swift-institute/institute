extension Source.Report {
    public enum Scope: Swift.String, Sendable, JSON.Serializable {
        case workspace
        case partial

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let scope = Self(rawValue: value) else {
                throw .typeMismatch(expected: "workspace or partial", got: value)
            }
            return scope
        }
    }
}
