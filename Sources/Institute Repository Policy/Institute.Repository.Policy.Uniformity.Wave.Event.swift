public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Uniformity.Wave {
    public struct Event: Sendable, Equatable {
        public let phase: String
        public let repository: String
        public let oldHead: String?
        public let newHead: String?
        public let oldGitignore: String?
        public let newGitignore: String?
        public let deletions: [String]?
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
            oldGitignore: String? = nil,
            newGitignore: String? = nil,
            deletions: [String]? = nil,
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
            self.oldGitignore = oldGitignore
            self.newGitignore = newGitignore
            self.deletions = deletions
            self.ruleset = ruleset
            self.bypassClosed = bypassClosed
            self.populationDigest = populationDigest
            self.policyDigest = policyDigest
            self.policySource = policySource
        }
    }
}

extension Institute.Repository.Policy.Uniformity.Wave.Event: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "phase": value.phase.json,
            "repository": value.repository.json,
            "oldHead": value.oldHead.json,
            "newHead": value.newHead.json,
            "oldGitignore": value.oldGitignore.json,
            "newGitignore": value.newGitignore.json,
            "deletions": value.deletions.json,
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
            oldGitignore: try Swift.String?(json: json["oldGitignore"]),
            newGitignore: try Swift.String?(json: json["newGitignore"]),
            deletions: try [Swift.String]?(json: json["deletions"]),
            ruleset: try Swift.Int64?(json: json["ruleset"]),
            bypassClosed: try Swift.Bool?(json: json["bypassClosed"]),
            populationDigest: try Swift.String?(json: json["populationDigest"]),
            policyDigest: try Swift.String?(json: json["policyDigest"]),
            policySource: try Swift.String?(json: json["policySource"])
        )
    }
}
