public import Institute_Model
public import JSON

extension Institute.Certification.Exclusion {
    /// Why a governed repository is absent from a snapshot's admitted
    /// members. Finite and typed: an exclusion the vocabulary cannot
    /// express is not an exclusion — the repository is either admitted or
    /// the snapshot is not constructible.
    public enum Reason: Swift.String, Swift.CaseIterable, Sendable, JSON.Serializable {
        /// The repository is archived: read-only on GitHub, out of the
        /// certifiable fleet by prior ruling.
        case archived

        /// The repository could not be read by the deriving identity at
        /// snapshot time. An inaccessible member is excluded loudly, never
        /// silently dropped.
        case inaccessible

        /// The repository was retired from the governed population by an
        /// explicit recorded ruling.
        case retired

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let reason = Self(rawValue: value) else {
                throw .typeMismatch(expected: "exclusion reason", got: value)
            }
            return reason
        }
    }
}
