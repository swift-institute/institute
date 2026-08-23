extension Repository.Policy.Caller.Wave {
    public struct Closure: Codable, Sendable, Equatable {
        public let repository: String
        public let head: String
        public let blob: String?
        public let callerDigest: String?
        public let callerMatches: Bool
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
            blob: String?,
            callerDigest: String?,
            callerMatches: Bool,
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
            self.blob = blob
            self.callerDigest = callerDigest
            self.callerMatches = callerMatches
            self.subjectStable = subjectStable
            self.ruleset = ruleset
            self.rulesetCanonical = rulesetCanonical
            self.bypassClosed = bypassClosed
            self.population = population
            self.policyDigest = policyDigest
            self.policySource = policySource
            self.accepted = callerMatches && subjectStable && rulesetCanonical && bypassClosed
        }
    }
}
