public import File_System
public import Institute_Model
public import JSON

extension Institute {
    /// One local hierarchy root registered on this machine: an identity,
    /// the physical root it currently resolves to, and how Institute may
    /// treat that root's filesystem content.
    ///
    /// ``locator`` is explicitly **not** identity. ``id`` is the registry
    /// key and is stable across a locator change — see
    /// ``relocated(to:)``. This type owns exactly identity, locator,
    /// ownership, and persistence: no branch, revision, package identity,
    /// or repository membership is recorded here, and none ever should be.
    public struct Hierarchy: Swift.Equatable, Swift.Sendable {
        /// The registry key. Never a filesystem path.
        public let id: ID

        /// Where ``id`` currently resolves on disk. Not identity: this can
        /// change underneath a stable ``id`` (see ``relocated(to:)``), and
        /// two distinct ids are never permitted to resolve to the same
        /// physical directory (enforced by ``Registry``, not by this type).
        public let locator: File.Directory

        /// Whether Institute may ever mutate this root's filesystem content.
        public let ownership: Ownership

        public init(id: ID, locator: File.Directory, ownership: Ownership) {
            self.id = id
            self.locator = locator
            self.ownership = ownership
        }
    }
}

extension Institute.Hierarchy {
    /// This hierarchy with ``locator`` replaced and everything else,
    /// including ``id``, unchanged.
    ///
    /// This is the operation a locator-change test exercises: the identity
    /// this type carries does not depend on where its root currently sits.
    public func relocated(to locator: File.Directory) -> Self {
        .init(id: id, locator: locator, ownership: ownership)
    }
}

extension Institute.Hierarchy: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "id": value.id.json,
            "locator": value.locator.path.description.json,
            "ownership": value.ownership.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        let expected: Swift.Set<Swift.String> = ["id", "locator", "ownership"]
        let actual = Swift.Set(object.keys)
        guard actual == expected else {
            throw .typeMismatch(
                expected: "hierarchy keys id, locator, and ownership",
                got: actual.sorted().joined(separator: ", ")
            )
        }
        guard let id = object["id"] else { throw .missingKey("id") }
        guard let locator = object["locator"] else { throw .missingKey("locator") }
        guard let ownership = object["ownership"] else { throw .missingKey("ownership") }

        let raw = try Swift.String(json: locator)
        let path: File.Path
        do throws(File.Path.Error) {
            path = try File.Path(raw)
        } catch {
            throw .typeMismatch(expected: "a valid filesystem path", got: "\(raw): \(error)")
        }

        return try Self(
            id: Institute.Hierarchy.ID(json: id),
            locator: File.Directory(path),
            ownership: Institute.Hierarchy.Ownership(json: ownership)
        )
    }
}
