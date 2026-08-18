public import Institute_Model
public import JSON

extension Institute.Certification {
    /// One immutable exact fleet snapshot: every admitted member bound to
    /// one exact revision, every governed absence typed, and the identity
    /// of the inventory the population was derived from.
    ///
    /// The snapshot is the *input* a certificate is about. It is
    /// content-addressed through the module's one digest seam
    /// (`Institute.Receipt.Sealed`): the same population in any
    /// construction order produces the same digest, and no machine path or
    /// volatile value participates.
    ///
    /// Invariants enforced at construction:
    /// - at least one member — an empty snapshot cannot exist, so nothing
    ///   downstream can be green over nothing;
    /// - one entry per repository identity across members *and* exclusions
    ///   — a repository cannot be both admitted and excluded, or appear
    ///   twice at different revisions.
    public struct Snapshot: Equatable, Sendable, Institute.Receipt.Sealed {
        public let version: Swift.Int
        public let kind: Swift.String
        public let inventoryCommit: Revision
        public let inventoryBlob: Swift.String
        public let members: [Member]
        public let exclusions: [Exclusion]

        public init(
            version: Swift.Int = 1,
            kind: Swift.String = "fleet-snapshot",
            inventoryCommit: Revision,
            inventoryBlob: Swift.String,
            members: [Member],
            exclusions: [Exclusion]
        ) throws(Institute.Error) {
            guard !members.isEmpty else {
                throw .repository("a snapshot must admit at least one member")
            }
            var keys = Set<Institute.Repository.Key>()
            for key in members.map(\.key) + exclusions.map(\.key) {
                guard keys.insert(key).inserted else {
                    throw .repository(
                        "duplicate snapshot entry for \(key.identity)"
                    )
                }
            }
            self.version = version
            self.kind = kind
            self.inventoryCommit = inventoryCommit
            self.inventoryBlob = inventoryBlob
            self.members = members.sorted {
                Institute.Repository.Key.precedes($0.key, $1.key)
            }
            self.exclusions = exclusions.sorted {
                Institute.Repository.Key.precedes($0.key, $1.key)
            }
        }
    }
}

extension Institute.Certification.Snapshot {
    /// The admitted member recorded for one repository identity, if any.
    public subscript(key: Institute.Repository.Key) -> Institute.Certification.Member? {
        members.first { $0.key == key }
    }

    public static func serialize(_ value: Self) -> JSON {
        [
            "version": value.version.json,
            "kind": value.kind.json,
            "inventoryCommit": value.inventoryCommit.json,
            "inventoryBlob": value.inventoryBlob.json,
            "members": value.members.json,
            "exclusions": value.exclusions.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let version = object["version"] else { throw .missingKey("version") }
        guard let kind = object["kind"] else { throw .missingKey("kind") }
        guard let inventoryCommit = object["inventoryCommit"] else {
            throw .missingKey("inventoryCommit")
        }
        guard let inventoryBlob = object["inventoryBlob"] else {
            throw .missingKey("inventoryBlob")
        }
        guard let members = object["members"] else { throw .missingKey("members") }
        guard let exclusions = object["exclusions"] else { throw .missingKey("exclusions") }
        do {
            return try Self(
                version: Swift.Int(json: version),
                kind: Swift.String(json: kind),
                inventoryCommit: Institute.Certification.Revision(json: inventoryCommit),
                inventoryBlob: Swift.String(json: inventoryBlob),
                members: [Institute.Certification.Member](json: members),
                exclusions: [Institute.Certification.Exclusion](json: exclusions)
            )
        } catch let error as JSON.Error {
            throw error
        } catch {
            throw .typeMismatch(
                expected: "structurally valid snapshot",
                got: Swift.String(describing: error)
            )
        }
    }
}
