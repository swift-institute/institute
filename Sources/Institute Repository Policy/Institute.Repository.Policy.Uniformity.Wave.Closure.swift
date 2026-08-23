public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Uniformity.Wave {
    public struct Closure: Sendable, Equatable {
        public let repository: String
        public let head: String
        public let gitignore: String?
        public let gitignoreDigest: String?
        public let shapeTerminal: Bool
        public let subjectStable: Bool
        public let ruleset: Int64?
        public let rulesetCanonical: Bool
        public let bypassClosed: Bool
        public let population: Commitment
        public let policyDigest: String
        public let policySource: String
        public let accepted: Bool

        public init(
            repository: String,
            head: String,
            gitignore: String?,
            gitignoreDigest: String?,
            shapeTerminal: Bool,
            subjectStable: Bool,
            ruleset: Int64?,
            rulesetCanonical: Bool,
            bypassClosed: Bool,
            population: Commitment,
            policyDigest: String,
            policySource: String
        ) {
            self.repository = repository
            self.head = head
            self.gitignore = gitignore
            self.gitignoreDigest = gitignoreDigest
            self.shapeTerminal = shapeTerminal
            self.subjectStable = subjectStable
            self.ruleset = ruleset
            self.rulesetCanonical = rulesetCanonical
            self.bypassClosed = bypassClosed
            self.population = population
            self.policyDigest = policyDigest
            self.policySource = policySource
            self.accepted = shapeTerminal && subjectStable && rulesetCanonical && bypassClosed
        }
    }
}

extension Institute.Repository.Policy.Uniformity.Wave.Closure: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "repository": value.repository.json,
            "head": value.head.json,
            "gitignore": value.gitignore.json,
            "gitignoreDigest": value.gitignoreDigest.json,
            "shapeTerminal": value.shapeTerminal.json,
            "subjectStable": value.subjectStable.json,
            "ruleset": value.ruleset.json,
            "rulesetCanonical": value.rulesetCanonical.json,
            "bypassClosed": value.bypassClosed.json,
            "population": value.population.json,
            "policyDigest": value.policyDigest.json,
            "policySource": value.policySource.json,
            "accepted": value.accepted.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            repository: try Swift.String(json: json["repository"]),
            head: try Swift.String(json: json["head"]),
            gitignore: try Swift.String?(json: json["gitignore"]),
            gitignoreDigest: try Swift.String?(json: json["gitignoreDigest"]),
            shapeTerminal: try Swift.Bool(json: json["shapeTerminal"]),
            subjectStable: try Swift.Bool(json: json["subjectStable"]),
            ruleset: try Swift.Int64?(json: json["ruleset"]),
            rulesetCanonical: try Swift.Bool(json: json["rulesetCanonical"]),
            bypassClosed: try Swift.Bool(json: json["bypassClosed"]),
            population: try Institute.Repository.Policy.Caller.Wave.Commitment(json: json["population"]),
            policyDigest: try Swift.String(json: json["policyDigest"]),
            policySource: try Swift.String(json: json["policySource"])
        )
    }
}
