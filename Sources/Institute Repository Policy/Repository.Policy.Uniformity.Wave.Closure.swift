extension Repository.Policy.Uniformity.Wave {
    public struct Closure: Codable, Sendable, Equatable {
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
