public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Caller.Wave {
    public struct Preflight: Sendable, Equatable {
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

extension Institute.Repository.Policy.Caller.Wave.Preflight: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "organization": value.organization.json,
            "repository": value.repository.json,
            "population": value.population.json,
            "recoveryDigest": value.recoveryDigest.json,
            "attestationDigest": value.attestationDigest.json,
            "accepted": value.accepted.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            organization: try Swift.String(json: json["organization"]),
            repository: try Swift.String(json: json["repository"]),
            population: try Institute.Repository.Policy.Caller.Wave.Commitment(json: json["population"]),
            recoveryDigest: try Swift.String(json: json["recoveryDigest"]),
            attestationDigest: try Swift.String(json: json["attestationDigest"]),
            accepted: try Swift.Bool(json: json["accepted"])
        )
    }
}
