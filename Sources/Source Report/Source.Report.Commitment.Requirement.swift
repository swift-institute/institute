extension Source.Report.Commitment {
    public struct Requirement: Equatable, Sendable, JSON.Serializable {
        public let subject: Swift.String
        public let engine: Source.Engine.ID
        public let artifacts: [Swift.String]
        public let rules: [Source.Rule.ID]

        public init(
            subject: Swift.String,
            engine: Source.Engine.ID,
            artifacts: [Swift.String],
            rules: [Source.Rule.ID]
        ) {
            self.subject = subject
            self.engine = engine
            self.artifacts = artifacts.sorted()
            self.rules = rules.sorted { ($0.engine.token, $0.token) < ($1.engine.token, $1.token) }
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "subject": value.subject.json,
                "engine": value.engine.json,
                "artifacts": value.artifacts.json,
                "rules": value.rules.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "requirement object", got: "other")
            }
            let expected: Set<Swift.String> = ["subject", "engine", "artifacts", "rules"]
            guard Set(object.keys) == expected else {
                throw .typeMismatch(expected: "requirement keys", got: "foreign keys")
            }
            guard let subject = object["subject"], let engine = object["engine"],
                let artifacts = object["artifacts"], let rules = object["rules"]
            else { throw .missingKey("requirement") }
            return try Self(
                subject: Swift.String(json: subject),
                engine: Source.Engine.ID(json: engine),
                artifacts: [Swift.String](json: artifacts),
                rules: [Source.Rule.ID](json: rules)
            )
        }
    }
}
