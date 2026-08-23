extension Repository.Policy.Caller.Wave {
    public struct Receipt: Codable, Sendable, Equatable {
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
