public import Institute_Model
public import JSON

extension Institute.Certification {
    /// The recorded outcome of one obligation: what actually happened when
    /// the owed work executed — or the typed fact that it did not.
    public struct Account: Equatable, Sendable, JSON.Serializable {
        public let obligation: Obligation
        public let outcome: Outcome

        public init(obligation: Obligation, outcome: Outcome) {
            self.obligation = obligation
            self.outcome = outcome
        }
    }
}

extension Institute.Certification.Account {
    /// What one executed (or unexecuted) obligation produced.
    public enum Outcome: Equatable, Sendable, JSON.Serializable {
        /// The obligation executed and succeeded. `evidence` addresses the
        /// supporting record — a receipt digest or an exact hosted-run
        /// coordinate — so the claim is auditable, never bare.
        case met(evidence: Swift.String)

        /// The obligation executed and failed, attributably. `diagnostic`
        /// carries the owning coordinate and first mechanical diagnostic.
        case failed(diagnostic: Swift.String)

        /// The obligation did not execute. An unmeasured obligation can
        /// never contribute green.
        case unmeasured(reason: Swift.String)

        public static func serialize(_ value: Self) -> JSON {
            switch value {
            case .met(let evidence):
                ["met": evidence.json]

            case .failed(let diagnostic):
                ["failed": diagnostic.json]

            case .unmeasured(let reason):
                ["unmeasured": reason.json]
            }
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary, object.count == 1 else {
                throw .typeMismatch(
                    expected: "single-key outcome object",
                    got: "other"
                )
            }
            if let evidence = object["met"] {
                return try .met(evidence: Swift.String(json: evidence))
            }
            if let diagnostic = object["failed"] {
                return try .failed(diagnostic: Swift.String(json: diagnostic))
            }
            if let reason = object["unmeasured"] {
                return try .unmeasured(reason: Swift.String(json: reason))
            }
            throw .typeMismatch(
                expected: "met, failed, or unmeasured",
                got: object.keys.sorted().joined(separator: ", ")
            )
        }
    }

    public static func serialize(_ value: Self) -> JSON {
        [
            "obligation": value.obligation.json,
            "outcome": value.outcome.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let obligation = object["obligation"] else { throw .missingKey("obligation") }
        guard let outcome = object["outcome"] else { throw .missingKey("outcome") }
        return try Self(
            obligation: Institute.Certification.Obligation(json: obligation),
            outcome: Outcome(json: outcome)
        )
    }
}
