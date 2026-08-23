public import Institute_Model
public import Byte_Primitives
import Byte_Primitives_Standard_Library_Integration
public import JSON

extension Institute.Repository.Policy.Uniformity.Wave {
    public struct Recovery: Sendable, Equatable {
        public let repository: String
        public let repositoryID: Int64
        public let rollbackHead: String
        public let manifest: Manifest
        public let shape: Shape
        public let payloadDigest: String
        public let population: Commitment
        public let canonicalRuleset: [Byte]
        public let integrationID: Int64
        public let policyDigest: String
        public let policySource: String
        public let priorRuleset: RulesetSnapshot?
        public let ruleset: RulesetSnapshot?

        public init(
            repository: String,
            repositoryID: Int64,
            rollbackHead: String,
            manifest: Manifest,
            shape: Shape,
            payloadDigest: String,
            population: Commitment,
            canonicalRuleset: [Byte],
            integrationID: Int64,
            policyDigest: String,
            policySource: String,
            priorRuleset: RulesetSnapshot?,
            ruleset: RulesetSnapshot?
        ) {
            self.repository = repository
            self.repositoryID = repositoryID
            self.rollbackHead = rollbackHead
            self.manifest = manifest
            self.shape = shape
            self.payloadDigest = payloadDigest
            self.population = population
            self.canonicalRuleset = canonicalRuleset
            self.integrationID = integrationID
            self.policyDigest = policyDigest
            self.policySource = policySource
            self.priorRuleset = priorRuleset
            self.ruleset = ruleset
        }
    }
}

extension Institute.Repository.Policy.Uniformity.Wave.Recovery: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "repository": value.repository.json,
            "repositoryID": value.repositoryID.json,
            "rollbackHead": value.rollbackHead.json,
            "manifest": value.manifest.json,
            "shape": value.shape.json,
            "payloadDigest": value.payloadDigest.json,
            "population": value.population.json,
            "canonicalRuleset": Swift.String(value.canonicalRuleset).json,
            "integrationID": value.integrationID.json,
            "policyDigest": value.policyDigest.json,
            "policySource": value.policySource.json,
            "priorRuleset": value.priorRuleset.json,
            "ruleset": value.ruleset.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            repository: try Swift.String(json: json["repository"]),
            repositoryID: try Swift.Int64(json: json["repositoryID"]),
            rollbackHead: try Swift.String(json: json["rollbackHead"]),
            manifest: try Institute.Repository.Policy.Caller.Wave.Manifest(json: json["manifest"]),
            shape: try Institute.Repository.Policy.Uniformity.Wave.Shape(json: json["shape"]),
            payloadDigest: try Swift.String(json: json["payloadDigest"]),
            population: try Institute.Repository.Policy.Caller.Wave.Commitment(json: json["population"]),
            canonicalRuleset: [Byte](try Swift.String(json: json["canonicalRuleset"]).utf8),
            integrationID: try Swift.Int64(json: json["integrationID"]),
            policyDigest: try Swift.String(json: json["policyDigest"]),
            policySource: try Swift.String(json: json["policySource"]),
            priorRuleset: try Institute.Repository.Policy.Caller.Wave.RulesetSnapshot?(json: json["priorRuleset"]),
            ruleset: try Institute.Repository.Policy.Caller.Wave.RulesetSnapshot?(json: json["ruleset"])
        )
    }
}
