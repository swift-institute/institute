public import Institute_Model
public import JSON

extension Institute.Planner.Canary {
    /// One way the candidate's outcome differs from the current planner's.
    /// A regression blocks adoption; an improvement is listed and does not.
    public struct Difference: Sendable, Equatable {
        public let kind: Kind
        public let detail: Swift.String

        public init(_ kind: Kind, _ detail: Swift.String) {
            self.kind = kind
            self.detail = detail
        }
    }
}

extension Institute.Planner.Canary.Difference {
    public enum Kind: Swift.String, Sendable, Equatable {
        case regression
        case improvement
    }
}

extension Institute.Planner.Canary.Difference: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        ["kind": value.kind.rawValue.json, "detail": value.detail.json]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let kind = Kind(rawValue: try Swift.String(json: json["kind"])) else {
            throw .typeMismatch(expected: "regression or improvement", got: "other")
        }
        return .init(kind, try Swift.String(json: json["detail"]))
    }
}
