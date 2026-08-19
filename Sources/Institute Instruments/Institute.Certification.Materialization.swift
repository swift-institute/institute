public import Institute_Model
public import JSON

extension Institute.Certification {
    /// The evaluation-input evidence for one admitted member: which exact
    /// commit was materialized, which tree that commit names, and every
    /// certification transformation applied to the materialized source
    /// before evaluation observed it.
    ///
    /// This receipt is the no-ambient-state law made checkable. Everything
    /// evaluation observed for the member derives from `revision` (the
    /// snapshot's exact commit, whose `tree` fixes the source bytes) plus
    /// the listed `transformations` — each itself deterministic and
    /// content-addressed. No machine path, hostname, or volatile value
    /// participates in the canonical serialization, so two certifiers
    /// materializing the same member at different destinations produce the
    /// same digest.
    public struct Materialization: Equatable, Sendable, Institute.Receipt.Sealed {
        public let version: Swift.Int
        public let kind: Swift.String
        public let key: Institute.Repository.Key
        public let revision: Revision
        /// The Git tree object `revision` names — the identity of the
        /// exact source bytes as verified at the materialized checkout,
        /// forty lowercase hexadecimal digits.
        public let tree: Swift.String
        public let transformations: [Transformation]

        public init(
            version: Swift.Int = 1,
            kind: Swift.String = "certification-materialization",
            key: Institute.Repository.Key,
            revision: Revision,
            tree: Swift.String,
            transformations: [Transformation]
        ) throws(Institute.Error) {
            guard
                tree.utf8.count == 40,
                tree.utf8.allSatisfy({ byte in
                    switch byte {
                    case 0x30...0x39, 0x61...0x66: true
                    default: false
                    }
                })
            else {
                throw .repository(
                    "a materialization tree must be exactly 40 lowercase "
                        + "hexadecimal digits: \(tree)"
                )
            }
            var files = Set<Swift.String>()
            for transformation in transformations {
                guard files.insert(transformation.file).inserted else {
                    throw .repository(
                        "duplicate materialization transformation for \(transformation.file)"
                    )
                }
            }
            self.version = version
            self.kind = kind
            self.key = key
            self.revision = revision
            self.tree = tree
            self.transformations = transformations.sorted { $0.file < $1.file }
        }
    }
}

extension Institute.Certification.Materialization {
    public static func serialize(_ value: Self) -> JSON {
        [
            "version": value.version.json,
            "kind": value.kind.json,
            "key": value.key.json,
            "revision": value.revision.json,
            "tree": value.tree.json,
            "transformations": value.transformations.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let version = object["version"] else { throw .missingKey("version") }
        guard let kind = object["kind"] else { throw .missingKey("kind") }
        guard let key = object["key"] else { throw .missingKey("key") }
        guard let revision = object["revision"] else { throw .missingKey("revision") }
        guard let tree = object["tree"] else { throw .missingKey("tree") }
        guard let transformations = object["transformations"] else {
            throw .missingKey("transformations")
        }
        do {
            return try Self(
                version: Swift.Int(json: version),
                kind: Swift.String(json: kind),
                key: Institute.Repository.Key(json: key),
                revision: Institute.Certification.Revision(json: revision),
                tree: Swift.String(json: tree),
                transformations: [Transformation](json: transformations)
            )
        } catch let error as JSON.Error {
            throw error
        } catch {
            throw .typeMismatch(
                expected: "a well-formed materialization receipt",
                got: Swift.String(describing: error)
            )
        }
    }
}
