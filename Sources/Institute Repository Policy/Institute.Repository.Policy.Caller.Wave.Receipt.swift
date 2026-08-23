public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Caller.Wave {
    public struct Receipt: Sendable, Equatable {
        public let repository: String
        public let oldHead: String
        public let newHead: String
        public let oldBlob: String
        public let newBlob: String
        public let ruleset: Int64
        public let callerChanged: Bool
        public let rulesetChanged: Bool
        public let changed: Bool
        public let bypassClosed: Bool
        public let population: Commitment
        public let policyDigest: String
        public let policySource: String

        public init(
            repository: String,
            oldHead: String,
            newHead: String,
            oldBlob: String,
            newBlob: String,
            ruleset: Int64,
            callerChanged: Bool,
            rulesetChanged: Bool,
            bypassClosed: Bool,
            population: Commitment,
            policyDigest: String,
            policySource: String
        ) {
            self.repository = repository
            self.oldHead = oldHead
            self.newHead = newHead
            self.oldBlob = oldBlob
            self.newBlob = newBlob
            self.ruleset = ruleset
            self.callerChanged = callerChanged
            self.rulesetChanged = rulesetChanged
            self.changed = callerChanged || rulesetChanged
            self.bypassClosed = bypassClosed
            self.population = population
            self.policyDigest = policyDigest
            self.policySource = policySource
        }
    }
}

extension Institute.Repository.Policy.Caller.Wave.Receipt: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "repository": value.repository.json,
            "oldHead": value.oldHead.json,
            "newHead": value.newHead.json,
            "oldBlob": value.oldBlob.json,
            "newBlob": value.newBlob.json,
            "ruleset": value.ruleset.json,
            "callerChanged": value.callerChanged.json,
            "rulesetChanged": value.rulesetChanged.json,
            "changed": value.changed.json,
            "bypassClosed": value.bypassClosed.json,
            "population": value.population.json,
            "policyDigest": value.policyDigest.json,
            "policySource": value.policySource.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            repository: try Swift.String(json: json["repository"]),
            oldHead: try Swift.String(json: json["oldHead"]),
            newHead: try Swift.String(json: json["newHead"]),
            oldBlob: try Swift.String(json: json["oldBlob"]),
            newBlob: try Swift.String(json: json["newBlob"]),
            ruleset: try Swift.Int64(json: json["ruleset"]),
            callerChanged: try Swift.Bool(json: json["callerChanged"]),
            rulesetChanged: try Swift.Bool(json: json["rulesetChanged"]),
            bypassClosed: try Swift.Bool(json: json["bypassClosed"]),
            population: try Institute.Repository.Policy.Caller.Wave.Commitment(json: json["population"]),
            policyDigest: try Swift.String(json: json["policyDigest"]),
            policySource: try Swift.String(json: json["policySource"])
        )
    }
}
