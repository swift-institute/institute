extension Repository.Policy.Caller.Wave {
    public struct Recensus: Codable, Sendable, Equatable {
        public let organizations: [String]
        public let examined: Int
        public let excluded: [String: Int]
        public let originalPopulation: Commitment
        public let currentPopulation: Commitment
        public let canonicalDigest: String
        public let policyDigest: String
        public let policySource: String
        public let receipts: Int
        public let closures: Int
        public let observations: [Observation]
        public let accepted: Bool

        public init(
            organizations: [String],
            examined: Int,
            excluded: [String: Int],
            originalPopulation: Commitment,
            currentPopulation: Commitment,
            canonicalDigest: String,
            policyDigest: String,
            policySource: String,
            receipts: Int,
            closures: Int,
            observations: [Observation],
            accepted: Bool
        ) {
            self.organizations = organizations
            self.examined = examined
            self.excluded = excluded
            self.originalPopulation = originalPopulation
            self.currentPopulation = currentPopulation
            self.canonicalDigest = canonicalDigest
            self.policyDigest = policyDigest
            self.policySource = policySource
            self.receipts = receipts
            self.closures = closures
            self.observations = observations
            self.accepted = accepted
        }
    }
}
