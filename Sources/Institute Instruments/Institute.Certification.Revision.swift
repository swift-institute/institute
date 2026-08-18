public import Institute_Model
public import JSON

extension Institute.Certification {
    /// One exact Git commit revision: the full forty-hexadecimal-digit
    /// object name, lowercase, and nothing else.
    ///
    /// Abbreviated names are refused by construction — an abbreviation is a
    /// lookup key, not an identity, and a snapshot member recorded by
    /// abbreviation could later resolve to a different object.
    public struct Revision: Equatable, Hashable, Sendable, JSON.Serializable {
        public let sha: Swift.String

        public init(_ sha: Swift.String) throws(Institute.Error) {
            guard sha.utf8.count == 40 else {
                throw .repository("revision must be exactly 40 hexadecimal digits: \(sha)")
            }
            guard
                sha.utf8.allSatisfy({ byte in
                    switch byte {
                    case 0x30...0x39, 0x61...0x66: true
                    default: false
                    }
                })
            else {
                throw .repository("revision must be lowercase hexadecimal: \(sha)")
            }
            self.sha = sha
        }
    }
}

extension Institute.Certification.Revision {
    public static func serialize(_ value: Self) -> JSON {
        value.sha.json
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        let value = try Swift.String(json: json)
        do {
            return try Self(value)
        } catch {
            throw .typeMismatch(expected: "40-digit lowercase hexadecimal revision", got: value)
        }
    }
}
