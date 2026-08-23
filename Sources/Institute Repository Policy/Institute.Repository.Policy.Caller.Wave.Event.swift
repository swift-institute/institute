public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Caller.Wave {
    public struct Event: Sendable, Equatable {
        public let phase: String
        public let repository: String
        public let oldHead: String?
        public let newHead: String?
        public let oldBlob: String?
        public let newBlob: String?
        public let ruleset: Int64?
        public let bypassClosed: Bool?
        public let populationDigest: String?
        public let policyDigest: String?
        public let policySource: String?

        public init(
            phase: String,
            repository: String,
            oldHead: String? = nil,
            newHead: String? = nil,
            oldBlob: String? = nil,
            newBlob: String? = nil,
            ruleset: Int64? = nil,
            bypassClosed: Bool? = nil,
            populationDigest: String? = nil,
            policyDigest: String? = nil,
            policySource: String? = nil
        ) {
            self.phase = phase
            self.repository = repository
            self.oldHead = oldHead
            self.newHead = newHead
            self.oldBlob = oldBlob
            self.newBlob = newBlob
            self.ruleset = ruleset
            self.bypassClosed = bypassClosed
            self.populationDigest = populationDigest
            self.policyDigest = policyDigest
            self.policySource = policySource
        }
    }
}

extension Institute.Repository.Policy.Caller.Wave.Event: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "phase": value.phase.json,
            "repository": value.repository.json,
            "oldHead": value.oldHead.json,
            "newHead": value.newHead.json,
            "oldBlob": value.oldBlob.json,
            "newBlob": value.newBlob.json,
            "ruleset": value.ruleset.json,
            "bypassClosed": value.bypassClosed.json,
            "populationDigest": value.populationDigest.json,
            "policyDigest": value.policyDigest.json,
            "policySource": value.policySource.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            phase: try Swift.String(json: json["phase"]),
            repository: try Swift.String(json: json["repository"]),
            oldHead: try Swift.String?(json: json["oldHead"]),
            newHead: try Swift.String?(json: json["newHead"]),
            oldBlob: try Swift.String?(json: json["oldBlob"]),
            newBlob: try Swift.String?(json: json["newBlob"]),
            ruleset: try Swift.Int64?(json: json["ruleset"]),
            bypassClosed: try Swift.Bool?(json: json["bypassClosed"]),
            populationDigest: try Swift.String?(json: json["populationDigest"]),
            policyDigest: try Swift.String?(json: json["policyDigest"]),
            policySource: try Swift.String?(json: json["policySource"])
        )
    }
}
