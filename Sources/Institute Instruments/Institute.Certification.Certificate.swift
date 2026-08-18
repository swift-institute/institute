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
    /// `coherenceReceipts` — typed references to
    /// `Institute.Coherence.Receipt` values, the one canonical receipt
    /// seam. A certificate references that seam; it does not duplicate
    /// it, and a reference of any other kind, or a duplicate reference,
    /// is refused.
    public struct Certificate: Equatable, Sendable, Institute.Receipt.Sealed {
        public let version: Swift.Int
        public let kind: Swift.String
        public let snapshot: Snapshot
        public let control: Control
        public let policy: Policy
        public let obligations: [Obligation]
        public let accounts: [Account]
        public let exceptions: [Exception]
        public let closure: [Closure.Coverage]
        public let coherenceReceipts: [Institute.Receipt.Reference]
        public let verdict: Verdict

        public init(
            version: Swift.Int = 1,
            kind: Swift.String = "fleet-certificate",
            snapshot: Snapshot,
            control: Control,
            policy: Policy,
            obligations: [Obligation],
            accounts: [Account],
            exceptions: [Exception],
            closure: [Closure.Coverage],
            coherenceReceipts: [Institute.Receipt.Reference]
        ) throws(Institute.Error) {
            let required = Set(obligations)
            guard required.count == obligations.count else {
                throw .repository("duplicate obligation in certification plan")
            }
            let admissible = Set(policy.admissible)
            for exception in exceptions {
                guard admissible.contains(exception.reason) else {
                    throw .repository(
                        "exception reason \(exception.reason.rawValue) is not admissible "
                            + "under this policy — waivers are policy-governed, never "
                            + "constructor-granted"
                    )
                }
            }
            var coverageConsumers = Set<Institute.Repository.Key>()
            for record in closure {
                guard coverageConsumers.insert(record.consumer).inserted else {
                    throw .repository(
                        "duplicate closure coverage for \(record.consumer.identity)"
                    )
                }
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
            self.policy = policy
            self.obligations = obligations.sorted(by: Obligation.precedes)
            self.accounts = accounts.sorted {
                Obligation.precedes($0.obligation, $1.obligation)
            }
            self.exceptions = exceptions.sorted {
                Obligation.precedes($0.obligation, $1.obligation)
            }
            self.closure = closure.sorted {
                Institute.Repository.Key.precedes($0.consumer, $1.consumer)
            }
            for reference in coherenceReceipts {
                guard reference.kind == Institute.Coherence.Receipt.canonicalKind else {
                    throw .repository(
                        "a certificate cites only ecosystem-coherence receipts; a "
                            + "reference of kind '\(reference.kind)' is refused"
                    )
                }
            }
            guard Set(coherenceReceipts).count == coherenceReceipts.count else {
                throw .repository("duplicate coherence receipt reference")
            }
            self.coherenceReceipts = coherenceReceipts.sorted { $0.digest < $1.digest }

            // Every package member owes an evaluated closure coverage
            // record: closure proof is a structural prerequisite of a
            // certificate, never decorative evidence. A member the closure
            // instrument never evaluated leaves the certificate
            // UNMEASURED even when its builds and tests are green.
            let uncoveredClosure = snapshot.members.contains { member in
                if case .package = member.kind {
                    !coverageConsumers.contains(member.key)
                } else {
                    false
                }
            }
            let uncovered = required.subtracting(covered)
            self.verdict =
                if accounts.contains(where: {
                    if case .failed = $0.outcome { true } else { false }
                }) || closure.contains(where: { !$0.passes }) {
                    .failed
                } else if !uncovered.isEmpty || uncoveredClosure
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
            "policy": value.policy.json,
            "obligations": value.obligations.json,
            "accounts": value.accounts.json,
            "exceptions": value.exceptions.json,
            "closure": value.closure.json,
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
        guard let policy = object["policy"] else { throw .missingKey("policy") }
        guard let obligations = object["obligations"] else { throw .missingKey("obligations") }
        guard let accounts = object["accounts"] else { throw .missingKey("accounts") }
        guard let exceptions = object["exceptions"] else { throw .missingKey("exceptions") }
        guard let closure = object["closure"] else { throw .missingKey("closure") }
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
                policy: Institute.Certification.Policy(json: policy),
                obligations: [Institute.Certification.Obligation](json: obligations),
                accounts: [Institute.Certification.Account](json: accounts),
                exceptions: [Institute.Certification.Exception](json: exceptions),
                closure: [Institute.Certification.Closure.Coverage](json: closure),
                coherenceReceipts: [Institute.Receipt.Reference](json: coherenceReceipts)
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
