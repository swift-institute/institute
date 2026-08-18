public import Institute_Model
public import JSON

extension Institute.Certification.Closure {
    /// The evaluated closure record for one consumer: the proofs its
    /// resolution produced — possibly none.
    ///
    /// Coverage exists so that *evaluated, zero internal edges* is a
    /// recorded observation, structurally distinct from *never
    /// evaluated*. A certificate requires coverage for every package
    /// member; a member without coverage leaves the certificate
    /// UNMEASURED regardless of its build and test accounts.
    public struct Coverage: Equatable, Sendable, JSON.Serializable {
        public let consumer: Institute.Repository.Key
        public let proofs: [Proof]

        public init(
            consumer: Institute.Repository.Key,
            proofs: [Proof]
        ) throws(Institute.Error) {
            for proof in proofs {
                guard proof.consumer == consumer else {
                    throw .repository(
                        "closure coverage for \(consumer.identity) contains a proof "
                            + "belonging to \(proof.consumer.identity)"
                    )
                }
            }
            self.consumer = consumer
            self.proofs = proofs.sorted { $0.location < $1.location }
        }

        /// Whether every proof in this coverage passes.
        public var passes: Swift.Bool {
            proofs.allSatisfy(\.passes)
        }
    }
}

extension Institute.Certification.Closure.Coverage {
    public static func serialize(_ value: Self) -> JSON {
        [
            "consumer": value.consumer.json,
            "proofs": value.proofs.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let consumer = object["consumer"] else { throw .missingKey("consumer") }
        guard let proofs = object["proofs"] else { throw .missingKey("proofs") }
        do {
            return try Self(
                consumer: Institute.Repository.Key(json: consumer),
                proofs: [Institute.Certification.Closure.Proof](json: proofs)
            )
        } catch let error as JSON.Error {
            throw error
        } catch {
            throw .typeMismatch(
                expected: "coverage whose proofs all belong to its consumer",
                got: Swift.String(describing: error)
            )
        }
    }
}
