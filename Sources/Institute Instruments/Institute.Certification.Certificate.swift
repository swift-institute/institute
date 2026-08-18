public import Institute_Model
public import JSON

extension Institute.Certification {
    /// One content-addressed fleet certificate: the complete, attributable
    /// account of every obligation one exact snapshot owed, under exact
    /// control identities.
    ///
    /// Construction is fail-closed:
    /// - every obligation must be covered by exactly one account or one
    ///   exception — uncovered, doubly covered, or unrequested work is
    ///   refused;
    /// - the verdict is derived (``Verdict``), never supplied.
    ///
    /// Composed-root integration evidence participates through
    /// `coherenceReceipts` — digests of `Institute.Coherence.Receipt`
    /// values, the one canonical receipt seam. A certificate references
    /// that seam; it does not duplicate it.
    public struct Certificate: Equatable, Sendable, Institute.Receipt.Sealed {
        public let version: Swift.Int
        public let kind: Swift.String
        public let snapshot: Snapshot
        public let control: Control
        public let obligations: [Obligation]
        public let accounts: [Account]
        public let exceptions: [Exception]
        public let coherenceReceipts: [Swift.String]
        public let verdict: Verdict

        public init(
            version: Swift.Int = 1,
            kind: Swift.String = "fleet-certificate",
            snapshot: Snapshot,
            control: Control,
            obligations: [Obligation],
            accounts: [Account],
            exceptions: [Exception],
            coherenceReceipts: [Swift.String]
        ) throws(Institute.Error) {
            let required = Set(obligations)
            guard required.count == obligations.count else {
                throw .repository("duplicate obligation in certification plan")
            }
            var covered = Set<Obligation>()
            for obligation in accounts.map(\.obligation) + exceptions.map(\.obligation) {
                guard required.contains(obligation) else {
                    throw .repository(
                        "account or exception for an unrequested obligation: "
                            + "\(obligation.key.identity) \(obligation.kind.rawValue) "
                            + obligation.platform.rawValue
                    )
                }
                guard covered.insert(obligation).inserted else {
                    throw .repository(
                        "obligation covered more than once: "
                            + "\(obligation.key.identity) \(obligation.kind.rawValue) "
                            + obligation.platform.rawValue
                    )
                }
            }

            self.version = version
            self.kind = kind
            self.snapshot = snapshot
            self.control = control
            self.obligations = obligations.sorted(by: Obligation.precedes)
            self.accounts = accounts.sorted {
                Obligation.precedes($0.obligation, $1.obligation)
            }
            self.exceptions = exceptions.sorted {
                Obligation.precedes($0.obligation, $1.obligation)
            }
            self.coherenceReceipts = coherenceReceipts.sorted()

            let uncovered = required.subtracting(covered)
            self.verdict =
                if accounts.contains(where: {
                    if case .failed = $0.outcome { true } else { false }
                }) {
                    .failed
                } else if !uncovered.isEmpty
                    || accounts.contains(where: {
                        if case .unmeasured = $0.outcome { true } else { false }
                    })
                {
                    .unmeasured
                } else {
                    .certified
                }
        }
    }
}

extension Institute.Certification.Certificate {
    public static func serialize(_ value: Self) -> JSON {
        [
            "version": value.version.json,
            "kind": value.kind.json,
            "snapshot": value.snapshot.json,
            "control": value.control.json,
            "obligations": value.obligations.json,
            "accounts": value.accounts.json,
            "exceptions": value.exceptions.json,
            "coherenceReceipts": value.coherenceReceipts.json,
            "verdict": value.verdict.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let version = object["version"] else { throw .missingKey("version") }
        guard let kind = object["kind"] else { throw .missingKey("kind") }
        guard let snapshot = object["snapshot"] else { throw .missingKey("snapshot") }
        guard let control = object["control"] else { throw .missingKey("control") }
        guard let obligations = object["obligations"] else { throw .missingKey("obligations") }
        guard let accounts = object["accounts"] else { throw .missingKey("accounts") }
        guard let exceptions = object["exceptions"] else { throw .missingKey("exceptions") }
        guard let coherenceReceipts = object["coherenceReceipts"] else {
            throw .missingKey("coherenceReceipts")
        }
        guard let verdict = object["verdict"] else { throw .missingKey("verdict") }
        let decoded: Self
        do {
            decoded = try Self(
                version: Swift.Int(json: version),
                kind: Swift.String(json: kind),
                snapshot: Institute.Certification.Snapshot(json: snapshot),
                control: Institute.Certification.Control(json: control),
                obligations: [Institute.Certification.Obligation](json: obligations),
                accounts: [Institute.Certification.Account](json: accounts),
                exceptions: [Institute.Certification.Exception](json: exceptions),
                coherenceReceipts: [Swift.String](json: coherenceReceipts)
            )
        } catch let error as JSON.Error {
            throw error
        } catch {
            throw .typeMismatch(
                expected: "structurally valid certificate",
                got: Swift.String(describing: error)
            )
        }
        // The verdict is derived, so a record claiming a different verdict
        // than its own accounting is corrupt, not merely stale.
        let claimed = try Institute.Certification.Verdict(json: verdict)
        guard claimed == decoded.verdict else {
            throw .typeMismatch(
                expected: decoded.verdict.rawValue,
                got: claimed.rawValue
            )
        }
        return decoded
    }
}
