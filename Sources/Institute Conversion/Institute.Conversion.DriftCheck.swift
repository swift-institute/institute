public import Institute_Model
public import Institute_Pages
public import Institute_Doctor

public import JSON

extension Institute.Conversion {
    /// One retained derived block's byte-compare drift check — the check
    /// Goal #126's completion criteria require of every retained derived
    /// block.
    public struct DriftCheck: Equatable, Sendable, JSON.Serializable {
        public let coordinate: Institute.Repository.Key
        public let path: Swift.String
        public let canonicalSource: Institute.Repository.Key
        public let outcome: Outcome

        public init(
            coordinate: Institute.Repository.Key,
            path: Swift.String,
            canonicalSource: Institute.Repository.Key,
            outcome: Outcome
        ) {
            self.coordinate = coordinate
            self.path = path
            self.canonicalSource = canonicalSource
            self.outcome = outcome
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "coordinate": value.coordinate.json,
                "path": value.path.json,
                "canonicalSource": value.canonicalSource.json,
                "outcome": value.outcome.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let coordinate = object["coordinate"] else { throw .missingKey("coordinate") }
            guard let path = object["path"] else { throw .missingKey("path") }
            guard let canonicalSource = object["canonicalSource"] else {
                throw .missingKey("canonicalSource")
            }
            guard let outcome = object["outcome"] else { throw .missingKey("outcome") }
            return try Self(
                coordinate: Institute.Repository.Key(json: coordinate),
                path: Swift.String(json: path),
                canonicalSource: Institute.Repository.Key(json: canonicalSource),
                outcome: Outcome(json: outcome)
            )
        }
    }
}

extension Institute.Conversion.DriftCheck {
    /// Sorted by (`coordinate`, `path`) — the receipt's drift-check
    /// ordering.
    package static func precedes(_ lhs: Self, _ rhs: Self) -> Swift.Bool {
        if lhs.coordinate != rhs.coordinate {
            return Institute.Repository.Key.precedes(lhs.coordinate, rhs.coordinate)
        }
        return lhs.path < rhs.path
    }
}
