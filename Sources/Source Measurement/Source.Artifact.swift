public import Path

extension Source {
    public struct Artifact: Hashable, Sendable {
        public let path: Path::Path
        public let kind: Kind
        public let purpose: Purpose
        public let provenance: Provenance
        public let digest: Digest

        public init(
            path: Path::Path,
            kind: Kind,
            purpose: Purpose,
            provenance: Provenance,
            digest: Digest
        ) {
            self.path = path
            self.kind = kind
            self.purpose = purpose
            self.provenance = provenance
            self.digest = digest
        }
    }
}

extension Source.Artifact: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "path": value.path.string.json,
            "kind": value.kind.json,
            "purpose": value.purpose.json,
            "provenance": value.provenance.json,
            "digest": value.digest.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard Set(object.keys) == ["path", "kind", "purpose", "provenance", "digest"] else {
            throw .typeMismatch(expected: "source artifact keys", got: "foreign keys")
        }
        guard let path = object["path"] else { throw .missingKey("path") }
        guard let kind = object["kind"] else { throw .missingKey("kind") }
        guard let purpose = object["purpose"] else { throw .missingKey("purpose") }
        guard let provenance = object["provenance"] else {
            throw .missingKey("provenance")
        }
        guard let digest = object["digest"] else { throw .missingKey("digest") }
        let text = try Swift.String(json: path)
        let parsed: Path::Path
        do throws(Path::Path.Error) {
            parsed = try Path::Path(validating: text)
        } catch {
            throw .typeMismatch(expected: "source artifact path", got: "invalid path")
        }
        return try Self(
            path: parsed,
            kind: Kind(json: kind),
            purpose: Purpose(json: purpose),
            provenance: Provenance(json: provenance),
            digest: Digest(json: digest)
        )
    }
}
