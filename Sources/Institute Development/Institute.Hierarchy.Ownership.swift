public import Institute_Model
public import JSON

extension Institute.Hierarchy {
    /// Whether Institute may ever mutate a hierarchy's filesystem
    /// content.
    ///
    /// This type records a permission only; nothing in this file — or in
    /// ``Registry`` — performs a filesystem mutation of any kind. Every
    /// registry operation on either case is read/validate only.
    public enum Ownership: Swift.String, Swift.Equatable, Swift.Sendable {
        /// Created and owned by Institute.
        case managed

        /// Pointed at by the registry but owned by the developer. Institute
        /// never writes to an adopted root's filesystem content.
        case adopted
    }
}

extension Institute.Hierarchy.Ownership: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        value.rawValue.json
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        let raw = try Swift.String(json: json)
        guard let value = Self(rawValue: raw) else {
            throw .typeMismatch(expected: "managed or adopted", got: raw)
        }
        return value
    }
}
