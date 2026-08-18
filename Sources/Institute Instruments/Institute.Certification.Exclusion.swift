public import Institute_Model
public import JSON

extension Institute.Certification {
    /// One typed absence: a governed repository that is deliberately not an
    /// admitted member of a snapshot, and why.
    public struct Exclusion: Equatable, Hashable, Sendable, JSON.Serializable {
        public let key: Institute.Repository.Key
        public let reason: Reason

        public init(key: Institute.Repository.Key, reason: Reason) {
            self.key = key
            self.reason = reason
        }
    }
}

extension Institute.Certification.Exclusion {
    public static func serialize(_ value: Self) -> JSON {
        [
            "key": value.key.json,
            "reason": value.reason.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let key = object["key"] else { throw .missingKey("key") }
        guard let reason = object["reason"] else { throw .missingKey("reason") }
        return try Self(
            key: Institute.Repository.Key(json: key),
            reason: Reason(json: reason)
        )
    }
}
