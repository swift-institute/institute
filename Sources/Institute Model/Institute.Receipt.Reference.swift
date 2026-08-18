public import JSON

extension Institute.Receipt {
    /// A typed reference to a sealed receipt: its content-addressing
    /// digest plus the kind of receipt it addresses.
    ///
    /// A reference exists so that one receipt can cite another as
    /// evidence without copying it: the digest freezes exactly which
    /// observation is cited, and the kind states what the citing party
    /// believes it is citing — a mismatch on either is detectable, never
    /// silent. An opaque string can be any of neither.
    public struct Reference: Equatable, Hashable, Sendable, JSON.Serializable {
        /// The SHA-256 of the referenced receipt's canonical
        /// serialization, as 64 lowercase hexadecimal characters.
        public let digest: Swift.String

        /// The referenced receipt's declared kind, verbatim.
        public let kind: Swift.String

        public init(
            digest: Swift.String,
            kind: Swift.String
        ) throws(Institute.Error) {
            guard
                digest.count == 64,
                digest.allSatisfy({ $0.isHexDigit && ($0.isNumber || $0.isLowercase) })
            else {
                throw .repository(
                    "a receipt reference digest must be 64 lowercase hexadecimal "
                        + "characters, not '\(digest)'"
                )
            }
            guard !kind.isEmpty else {
                throw .repository("a receipt reference must name the kind it cites")
            }
            self.digest = digest
            self.kind = kind
        }

        /// The reference addressing `receipt` as it stands: the digest is
        /// computed here, over the sealed canonical serialization, so a
        /// reference can never be constructed citing bytes nobody hashed.
        public init(
            of receipt: some Institute.Receipt.Sealed,
            kind: Swift.String
        ) throws(Institute.Error) {
            try self.init(digest: receipt.digest, kind: kind)
        }
    }
}

extension Institute.Receipt.Reference {
    public static func serialize(_ value: Self) -> JSON {
        [
            "digest": value.digest.json,
            "kind": value.kind.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let digest = object["digest"] else { throw .missingKey("digest") }
        guard let kind = object["kind"] else { throw .missingKey("kind") }
        do {
            return try Self(
                digest: Swift.String(json: digest),
                kind: Swift.String(json: kind)
            )
        } catch let error as JSON.Error {
            throw error
        } catch {
            throw .typeMismatch(
                expected: "a well-formed receipt reference",
                got: Swift.String(describing: error)
            )
        }
    }
}
