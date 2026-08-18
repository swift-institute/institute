public import Institute_Model
public import JSON

extension Institute.Certification.Closure {
    /// One classified Institute-internal dependency edge: which consumer
    /// resolved which location, and what that resolution proves.
    public struct Proof: Equatable, Sendable, JSON.Serializable {
        public let consumer: Institute.Repository.Key
        public let location: Swift.String
        public let verdict: Verdict

        public init(
            consumer: Institute.Repository.Key,
            location: Swift.String,
            verdict: Verdict
        ) {
            self.consumer = consumer
            self.location = location
            self.verdict = verdict
        }

        /// Whether this edge keeps the certificate lawful.
        public var passes: Swift.Bool {
            switch verdict {
            case .exact, .local, .excludedMember: true
            case .ungoverned, .revisionSkew, .networkEscape, .unexpectedLocal,
                .unclassifiable:
                false
            }
        }
    }
}

extension Institute.Certification.Closure.Proof {
    public static func serialize(_ value: Self) -> JSON {
        [
            "consumer": value.consumer.json,
            "location": value.location.json,
            "verdict": value.verdict.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let consumer = object["consumer"] else { throw .missingKey("consumer") }
        guard let location = object["location"] else { throw .missingKey("location") }
        guard let verdict = object["verdict"] else { throw .missingKey("verdict") }
        return try Self(
            consumer: Institute.Repository.Key(json: consumer),
            location: Swift.String(json: location),
            verdict: Institute.Certification.Closure.Verdict(json: verdict)
        )
    }
}
