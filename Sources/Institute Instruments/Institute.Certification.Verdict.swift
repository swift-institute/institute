public import Institute_Model
public import JSON

extension Institute.Certification {
    /// A certificate's overall verdict — always derived from the complete
    /// obligation accounting, never asserted.
    ///
    /// A measured failure dominates: a certificate with any failed account
    /// is `failed` even if other obligations went unmeasured. With no
    /// failure, any unmeasured or uncovered obligation makes the whole
    /// certificate `unmeasured` — never green by omission. Only a
    /// certificate whose every obligation is met or lawfully excepted is
    /// `certified`.
    public enum Verdict: Swift.String, Equatable, Sendable, JSON.Serializable {
        case certified
        case failed
        case unmeasured

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let verdict = Self(rawValue: value) else {
                throw .typeMismatch(expected: "certification verdict", got: value)
            }
            return verdict
        }
    }
}
