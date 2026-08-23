public import Institute_Model
public import Foundation

extension Institute.Repository.Policy.Uniformity.Wave {
    public struct Recovery: Codable, Sendable, Equatable {
        public let repository: String
        public let repositoryID: Int64
        public let rollbackHead: String
        public let manifest: Manifest
        public let shape: Shape
        public let payloadDigest: String
        public let population: Commitment
        public let canonicalRuleset: Data
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
            canonicalRuleset: Data,
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
