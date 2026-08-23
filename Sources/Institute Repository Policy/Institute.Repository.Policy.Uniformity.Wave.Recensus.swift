public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Uniformity.Wave {
    public struct Recensus: Sendable, Equatable {
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

extension Institute.Repository.Policy.Uniformity.Wave.Recensus: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "organizations": value.organizations.json,
            "examined": value.examined.json,
            "excluded": value.excluded.json,
            "originalPopulation": value.originalPopulation.json,
            "currentPopulation": value.currentPopulation.json,
            "canonicalDigest": value.canonicalDigest.json,
            "policyDigest": value.policyDigest.json,
            "policySource": value.policySource.json,
            "receipts": value.receipts.json,
            "closures": value.closures.json,
            "observations": value.observations.json,
            "accepted": value.accepted.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            organizations: try [Swift.String](json: json["organizations"]),
            examined: try Swift.Int(json: json["examined"]),
            excluded: try [Swift.String: Swift.Int](json: json["excluded"]),
            originalPopulation: try Institute.Repository.Policy.Caller.Wave.Commitment(json: json["originalPopulation"]),
            currentPopulation: try Institute.Repository.Policy.Caller.Wave.Commitment(json: json["currentPopulation"]),
            canonicalDigest: try Swift.String(json: json["canonicalDigest"]),
            policyDigest: try Swift.String(json: json["policyDigest"]),
            policySource: try Swift.String(json: json["policySource"]),
            receipts: try Swift.Int(json: json["receipts"]),
            closures: try Swift.Int(json: json["closures"]),
            observations: try [Institute.Repository.Policy.Uniformity.Wave.Observation](json: json["observations"]),
            accepted: try Swift.Bool(json: json["accepted"])
        )
    }
}
