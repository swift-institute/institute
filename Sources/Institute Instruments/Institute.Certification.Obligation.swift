public import Institute_Model
public import JSON

extension Institute.Certification {
    /// One required unit of certification work: a member owes one kind of
    /// execution on one platform.
    ///
    /// Obligations are derived deterministically from the snapshot plus
    /// policy before anything executes; the certificate then accounts for
    /// every one of them. Work that was never obligated cannot make a
    /// certificate green, and an obligation with no account makes the
    /// certificate unmeasured — green-by-omission is unrepresentable.
    public struct Obligation: Equatable, Hashable, Sendable, JSON.Serializable {
        public let key: Institute.Repository.Key
        public let kind: Kind
        public let platform: Platform

        public init(
            key: Institute.Repository.Key,
            kind: Kind,
            platform: Platform
        ) {
            self.key = key
            self.kind = kind
            self.platform = platform
        }
    }
}

extension Institute.Certification.Obligation {
    /// What kind of execution is owed.
    public enum Kind: Swift.String, Swift.CaseIterable, Sendable, JSON.Serializable {
        /// The member package must build.
        case build

        /// The member package's own test suites must execute.
        case test

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let kind = Self(rawValue: value) else {
                throw .typeMismatch(expected: "obligation kind", got: value)
            }
            return kind
        }
    }

    public static func serialize(_ value: Self) -> JSON {
        [
            "key": value.key.json,
            "kind": value.kind.json,
            "platform": value.platform.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let key = object["key"] else { throw .missingKey("key") }
        guard let kind = object["kind"] else { throw .missingKey("kind") }
        guard let platform = object["platform"] else { throw .missingKey("platform") }
        return try Self(
            key: Institute.Repository.Key(json: key),
            kind: Kind(json: kind),
            platform: Institute.Certification.Platform(json: platform)
        )
    }

    /// Deterministic ordering for canonical serialization.
    package static func precedes(_ lhs: Self, _ rhs: Self) -> Swift.Bool {
        if lhs.key != rhs.key {
            return Institute.Repository.Key.precedes(lhs.key, rhs.key)
        }
        if lhs.kind != rhs.kind {
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
        return lhs.platform.rawValue < rhs.platform.rawValue
    }
}
