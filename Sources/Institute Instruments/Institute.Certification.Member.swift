public import Institute_Model
public import JSON

extension Institute.Certification {
    /// One admitted snapshot member: a repository identity bound to one
    /// exact revision, with its typed obligation kind.
    public struct Member: Equatable, Hashable, Sendable, JSON.Serializable {
        public let key: Institute.Repository.Key
        public let revision: Revision
        public let kind: Kind

        public init(
            key: Institute.Repository.Key,
            revision: Revision,
            kind: Kind
        ) {
            self.key = key
            self.revision = revision
            self.kind = kind
        }
    }
}

extension Institute.Certification.Member {
    public static func serialize(_ value: Self) -> JSON {
        [
            "key": value.key.json,
            "revision": value.revision.json,
            "kind": value.kind.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let key = object["key"] else { throw .missingKey("key") }
        guard let revision = object["revision"] else { throw .missingKey("revision") }
        guard let kind = object["kind"] else { throw .missingKey("kind") }
        return try Self(
            key: Institute.Repository.Key(json: key),
            revision: Institute.Certification.Revision(json: revision),
            kind: Kind(json: kind)
        )
    }
}
