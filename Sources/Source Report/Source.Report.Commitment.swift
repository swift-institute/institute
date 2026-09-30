extension Source.Report {
  public struct Commitment: Equatable, Sendable, JSON.Serializable {
    public let subjects: [Source.Subject]
    public let engines: [Engine]
    public let rules: [Rule]
    public let requirements: [Requirement]
    public let predicates: [Predicate]
    public let predicateRequirements: [PredicateRequirement]

    public init(
      subjects: [Source.Subject],
      engines: [Engine],
      rules: [Rule],
      requirements: [Requirement],
      predicates: [Predicate],
      predicateRequirements: [PredicateRequirement]
    ) {
      self.subjects = subjects.sorted { $0.identity < $1.identity }
      self.engines = engines.sorted { $0.id.token < $1.id.token }
      self.rules = rules.sorted {
        ($0.id.engine.token, $0.id.token) < ($1.id.engine.token, $1.id.token)
      }
      self.requirements = requirements.sorted {
        ($0.subject, $0.engine.token) < ($1.subject, $1.engine.token)
      }
      self.predicates = predicates.sorted {
        ($0.id.engine.token, $0.id.token) < ($1.id.engine.token, $1.id.token)
      }
      self.predicateRequirements = predicateRequirements.sorted {
        ($0.subject, $0.artifacts.joined(separator: "\u{0}"))
          < ($1.subject, $1.artifacts.joined(separator: "\u{0}"))
      }
    }

    public static func serialize(_ value: Self) -> JSON {
      [
        "subjects": value.subjects.json,
        "engines": value.engines.json,
        "rules": value.rules.json,
        "requirements": value.requirements.json,
        "predicates": value.predicates.json,
        "predicateRequirements": value.predicateRequirements.json,
      ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      guard let object = json.dictionary else {
        throw .typeMismatch(expected: "object", got: "non-object")
      }
      let expected: Set<Swift.String> = [
        "subjects", "engines", "rules", "requirements", "predicates",
        "predicateRequirements",
      ]
      guard Set(object.keys) == expected else {
        throw .typeMismatch(expected: "commitment keys", got: "foreign keys")
      }
      func required(_ key: Swift.String) throws(JSON.Error) -> JSON {
        guard let value = object[key] else { throw .missingKey(key) }
        return value
      }
      return try Self(
        subjects: [Source.Subject](json: required("subjects")),
        engines: [Engine](json: required("engines")),
        rules: [Rule](json: required("rules")),
        requirements: [Requirement](json: required("requirements")),
        predicates: [Predicate](json: required("predicates")),
        predicateRequirements: [PredicateRequirement](
          json: required("predicateRequirements")
        )
      )
    }
  }
}
