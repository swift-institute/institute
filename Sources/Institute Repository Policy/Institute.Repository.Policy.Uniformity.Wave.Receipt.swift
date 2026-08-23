public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Uniformity.Wave {
    public struct Receipt: Sendable, Equatable {
        public let repository: String
        public let oldHead: String
        public let newHead: String
        public let oldGitignore: String?
        public let newGitignore: String
        public let deleted: [String]
        public let ruleset: Int64
        public let shapeChanged: Bool
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
            oldGitignore: String?,
            newGitignore: String,
            deleted: [String],
            ruleset: Int64,
            shapeChanged: Bool,
            rulesetChanged: Bool,
            bypassClosed: Bool,
            population: Commitment,
            policyDigest: String,
            policySource: String
        ) {
            self.repository = repository
            self.oldHead = oldHead
            self.newHead = newHead
            self.oldGitignore = oldGitignore
            self.newGitignore = newGitignore
            self.deleted = deleted
            self.ruleset = ruleset
            self.shapeChanged = shapeChanged
            self.rulesetChanged = rulesetChanged
            self.changed = shapeChanged || rulesetChanged
            self.bypassClosed = bypassClosed
            self.population = population
            self.policyDigest = policyDigest
            self.policySource = policySource
        }
    }
}

extension Institute.Repository.Policy.Uniformity.Wave.Receipt: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "repository": value.repository.json,
            "oldHead": value.oldHead.json,
            "newHead": value.newHead.json,
            "oldGitignore": value.oldGitignore.json,
            "newGitignore": value.newGitignore.json,
            "deleted": value.deleted.json,
            "ruleset": value.ruleset.json,
            "shapeChanged": value.shapeChanged.json,
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
            oldGitignore: try Swift.String?(json: json["oldGitignore"]),
            newGitignore: try Swift.String(json: json["newGitignore"]),
            deleted: try [Swift.String](json: json["deleted"]),
            ruleset: try Swift.Int64(json: json["ruleset"]),
            shapeChanged: try Swift.Bool(json: json["shapeChanged"]),
            rulesetChanged: try Swift.Bool(json: json["rulesetChanged"]),
            bypassClosed: try Swift.Bool(json: json["bypassClosed"]),
            population: try Institute.Repository.Policy.Caller.Wave.Commitment(json: json["population"]),
            policyDigest: try Swift.String(json: json["policyDigest"]),
            policySource: try Swift.String(json: json["policySource"])
        )
    }
}
