public import JSON

extension Institute.Workspace.Dependency {
    public enum Binding: Swift.String, Sendable, Equatable, JSON.Serializable {
        case localInstituteClosure = "local-institute-closure"
        case remoteAllowed = "remote-allowed"

        public static func serialize(_ value: Self) -> JSON {
            value.rawValue.json
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let binding = Self(rawValue: value) else {
                throw .typeMismatch(expected: "workspace dependency binding", got: value)
            }
            return binding
        }
    }
}
