extension Repository.Policy.Uniformity.Wave {
    public struct Preflight: Codable, Sendable, Equatable {
        public let organization: String
        public let repository: String
        public let population: Commitment
        public let recoveryDigest: String
        public let attestationDigest: String
        public let accepted: Bool

        public init(
            organization: String,
            repository: String,
            population: Commitment,
            recoveryDigest: String,
            attestationDigest: String,
            accepted: Bool
        ) {
            self.organization = organization
            self.repository = repository
            self.population = population
            self.recoveryDigest = recoveryDigest
            self.attestationDigest = attestationDigest
            self.accepted = accepted
        }
    }
}
