public import Institute_Model
public import JSON

extension Institute.Certification {
    /// An execution platform a certification obligation is owed on.
    ///
    /// The obligated set is an explicit *input* to certification — never
    /// inferred from wherever a run happened to execute. A platform that
    /// was obligated but not executed is UNMEASURED, not green.
    public enum Platform: Swift.String, Swift.CaseIterable, Sendable, JSON.Serializable {
        case macos
        case linux
        case windows

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let platform = Self(rawValue: value) else {
                throw .typeMismatch(expected: "certification platform", got: value)
            }
            return platform
        }
    }
}
