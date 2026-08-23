extension Repository.Policy.Uniformity.Wave {
    public struct Receipt: Codable, Sendable, Equatable {
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
