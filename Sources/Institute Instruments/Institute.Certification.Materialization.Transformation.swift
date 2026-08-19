public import Institute_Model
public import JSON

extension Institute.Certification.Materialization {
    /// One lawful certification transformation of materialized source: a
    /// deterministic rewrite of one repository-relative file, identified by
    /// what it semantically does, never by where it physically happened.
    ///
    /// The canonical example is manifest source redirection: a declared
    /// remote dependency clause is replaced so the dependency resolves to
    /// the exact local materialization of the corresponding snapshot
    /// member. `dependency` names which declaration was redirected and
    /// `target` names the exact revision it now resolves to — the two
    /// facts that survive across machines. The redirected clause's local
    /// path is per-machine working state and is deliberately absent: two
    /// certifiers applying the same semantic transformation at different
    /// destinations must produce the same digest.
    public struct Transformation: Equatable, Sendable, JSON.Serializable {
        /// The transformed file, repository-relative (for example
        /// `Package.swift`).
        public let file: Swift.String
        /// The Institute identity of the redirected dependency.
        public let dependency: Swift.String
        /// The exact snapshot revision the dependency resolves to after
        /// the transformation.
        public let target: Institute.Certification.Revision

        public init(
            file: Swift.String,
            dependency: Swift.String,
            target: Institute.Certification.Revision
        ) throws(Institute.Error) {
            guard !file.isEmpty else {
                throw .repository("a transformation must name the file it rewrites")
            }
            guard !dependency.isEmpty else {
                throw .repository("a transformation must name the dependency it redirects")
            }
            self.file = file
            self.dependency = dependency
            self.target = target
        }
    }
}

extension Institute.Certification.Materialization.Transformation {
    public static func serialize(_ value: Self) -> JSON {
        [
            "file": value.file.json,
            "dependency": value.dependency.json,
            "target": value.target.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let file = object["file"] else { throw .missingKey("file") }
        guard let dependency = object["dependency"] else { throw .missingKey("dependency") }
        guard let target = object["target"] else { throw .missingKey("target") }
        do {
            return try Self(
                file: Swift.String(json: file),
                dependency: Swift.String(json: dependency),
                target: Institute.Certification.Revision(json: target)
            )
        } catch let error as JSON.Error {
            throw error
        } catch {
            throw .typeMismatch(
                expected: "a well-formed materialization transformation",
                got: Swift.String(describing: error)
            )
        }
    }
}
