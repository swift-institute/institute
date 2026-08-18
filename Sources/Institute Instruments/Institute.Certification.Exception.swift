public import Institute_Model
public import JSON

extension Institute.Certification {
    /// One typed, authorized skip: an obligation deliberately not executed,
    /// with the recorded authority that permits the absence.
    ///
    /// An exception is part of the addressed certificate — skips are
    /// evidence, never omissions. An obligation that is neither accounted
    /// nor excepted leaves the certificate UNMEASURED.
    public struct Exception: Equatable, Hashable, Sendable, JSON.Serializable {
        public let obligation: Obligation
        public let reason: Reason

        /// The recorded ruling that authorizes this exception — an exact
        /// GitHub Issue coordinate such as
        /// `swift-institute/.github#600`, never free prose alone.
        public let authority: Swift.String

        public init(
            obligation: Obligation,
            reason: Reason,
            authority: Swift.String
        ) {
            self.obligation = obligation
            self.reason = reason
            self.authority = authority
        }
    }
}

extension Institute.Certification.Exception {
    /// Why an obligation is lawfully not executed.
    public enum Reason: Swift.String, Swift.CaseIterable, Sendable, JSON.Serializable {
        /// The member has no execution of this kind by design — for
        /// example, a control-plane member with no package to build.
        case notApplicable

        /// The obligation is suspended by a recorded defect at an exact
        /// owner (a known toolchain or platform defect), pending repair.
        case knownDefect

        /// The platform obligation is not executable on any supported
        /// zero-cost backend for this member, by recorded ruling.
        case unsupportedPlatform

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let reason = Self(rawValue: value) else {
                throw .typeMismatch(expected: "exception reason", got: value)
            }
            return reason
        }
    }

    public static func serialize(_ value: Self) -> JSON {
        [
            "obligation": value.obligation.json,
            "reason": value.reason.json,
            "authority": value.authority.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let obligation = object["obligation"] else { throw .missingKey("obligation") }
        guard let reason = object["reason"] else { throw .missingKey("reason") }
        guard let authority = object["authority"] else { throw .missingKey("authority") }
        return try Self(
            obligation: Institute.Certification.Obligation(json: obligation),
            reason: Reason(json: reason),
            authority: Swift.String(json: authority)
        )
    }
}
