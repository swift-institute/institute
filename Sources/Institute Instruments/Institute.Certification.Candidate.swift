public import Institute_Model
public import JSON

extension Institute.Certification {
    /// One immutable fleet-campaign candidate: an exact snapshot whose
    /// members carry provenance — candidate pull-request heads for the
    /// campaign's affected repositories, exact baseline revisions for
    /// every unchanged member — bound to the campaign that derived it.
    ///
    /// Campaign membership is centrally derived (`swift-institute/.github#624`):
    /// a pull request never self-declares membership. Each candidate head
    /// records the expected patch digest, so any unexpected head or patch
    /// movement is detectable and invalidates admission until a new
    /// candidate is derived and certified.
    public struct Candidate: Equatable, Sendable, Institute.Receipt.Sealed {
        public let version: Swift.Int
        public let kind: Swift.String

        /// The campaign identity that derived this candidate.
        public let campaign: Swift.String

        /// The exact snapshot under certification: candidate heads for
        /// affected members, baseline revisions for the rest.
        public let snapshot: Snapshot

        /// Provenance for every affected member. Keys must be admitted
        /// snapshot members; a provenance entry for a non-member is
        /// refused, as is an affected member whose snapshot revision
        /// disagrees with its candidate head.
        public let heads: [Head]

        public init(
            version: Swift.Int = 1,
            kind: Swift.String = "fleet-candidate",
            campaign: Swift.String,
            snapshot: Snapshot,
            heads: [Head]
        ) throws(Institute.Error) {
            guard !campaign.isEmpty else {
                throw .repository("a candidate requires a campaign identity")
            }
            var seen = Set<Institute.Repository.Key>()
            for head in heads {
                guard seen.insert(head.key).inserted else {
                    throw .repository(
                        "duplicate candidate head for \(head.key.identity)"
                    )
                }
                guard let member = snapshot[head.key] else {
                    throw .repository(
                        "candidate head for a repository that is not an "
                            + "admitted snapshot member: \(head.key.identity)"
                    )
                }
                guard member.revision == head.revision else {
                    throw .repository(
                        "candidate head revision disagrees with the snapshot "
                            + "member for \(head.key.identity)"
                    )
                }
            }
            self.version = version
            self.kind = kind
            self.campaign = campaign
            self.snapshot = snapshot
            self.heads = heads.sorted {
                Institute.Repository.Key.precedes($0.key, $1.key)
            }
        }
    }
}

extension Institute.Certification.Candidate {
    /// One affected member's candidate provenance: the pull request whose
    /// head the snapshot admits, and the exact patch that pull request is
    /// expected to carry.
    public struct Head: Equatable, Hashable, Sendable, JSON.Serializable {
        public let key: Institute.Repository.Key
        public let pullRequest: Swift.Int
        public let revision: Institute.Certification.Revision

        /// Digest of the deterministic patch the campaign generated for
        /// this member. Admission verifies the pull request's actual
        /// content against this digest; any other edit invalidates it.
        public let patchDigest: Swift.String

        public init(
            key: Institute.Repository.Key,
            pullRequest: Swift.Int,
            revision: Institute.Certification.Revision,
            patchDigest: Swift.String
        ) {
            self.key = key
            self.pullRequest = pullRequest
            self.revision = revision
            self.patchDigest = patchDigest
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "key": value.key.json,
                "pullRequest": value.pullRequest.json,
                "revision": value.revision.json,
                "patchDigest": value.patchDigest.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let key = object["key"] else { throw .missingKey("key") }
            guard let pullRequest = object["pullRequest"] else {
                throw .missingKey("pullRequest")
            }
            guard let revision = object["revision"] else { throw .missingKey("revision") }
            guard let patchDigest = object["patchDigest"] else {
                throw .missingKey("patchDigest")
            }
            return try Self(
                key: Institute.Repository.Key(json: key),
                pullRequest: Swift.Int(json: pullRequest),
                revision: Institute.Certification.Revision(json: revision),
                patchDigest: Swift.String(json: patchDigest)
            )
        }
    }

    public static func serialize(_ value: Self) -> JSON {
        [
            "version": value.version.json,
            "kind": value.kind.json,
            "campaign": value.campaign.json,
            "snapshot": value.snapshot.json,
            "heads": value.heads.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let version = object["version"] else { throw .missingKey("version") }
        guard let kind = object["kind"] else { throw .missingKey("kind") }
        guard let campaign = object["campaign"] else { throw .missingKey("campaign") }
        guard let snapshot = object["snapshot"] else { throw .missingKey("snapshot") }
        guard let heads = object["heads"] else { throw .missingKey("heads") }
        do {
            return try Self(
                version: Swift.Int(json: version),
                kind: Swift.String(json: kind),
                campaign: Swift.String(json: campaign),
                snapshot: Institute.Certification.Snapshot(json: snapshot),
                heads: [Head](json: heads)
            )
        } catch let error as JSON.Error {
            throw error
        } catch {
            throw .typeMismatch(
                expected: "structurally valid candidate",
                got: Swift.String(describing: error)
            )
        }
    }
}
