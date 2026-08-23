public import Institute_Model
public import Byte_Primitives

extension Institute.Repository.Policy.Uniformity.Wave {
    public struct Request: Sendable {
        public let repository: String
        public let expectedRepositoryID: Int64
        public let expectedHead: String
        public let expectedManifest: Manifest
        public let expectedShape: Shape
        public let payload: [Byte]
        public let payloadDigest: String
        public let canonicalRuleset: [Byte]
        public let integrationID: Int64
        public let population: Commitment
        public let policyDigest: String
        public let policySource: String
        public let commitMessage: String

        public init(
            repository: String,
            expectedRepositoryID: Int64,
            expectedHead: String,
            expectedManifest: Manifest,
            expectedShape: Shape,
            payload: [Byte],
            canonicalRuleset: [Byte],
            integrationID: Int64,
            population: Commitment,
            policyDigest: String,
            policySource: String,
            commitMessage: String
        ) {
            self.repository = repository
            self.expectedRepositoryID = expectedRepositoryID
            self.expectedHead = expectedHead
            self.expectedManifest = expectedManifest
            self.expectedShape = expectedShape
            self.payload = payload
            self.payloadDigest = Institute.Repository.Policy.Caller.Wave.digest(payload)
            self.canonicalRuleset = canonicalRuleset
            self.integrationID = integrationID
            self.population = population
            self.policyDigest = policyDigest
            self.policySource = policySource
            self.commitMessage = commitMessage
        }
    }
}
