public import Institute_Model
public import Byte_Primitives

extension Institute.Repository.Policy.Caller.Wave {
    public struct Request: Sendable {
        public let repository: String
        public let expectedRepositoryID: Int64
        public let expectedHead: String
        public let expectedManifest: Manifest
        public let expectedBlob: String
        public let caller: [Byte]
        public let callerDigest: String
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
            expectedBlob: String,
            caller: [Byte],
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
            self.expectedBlob = expectedBlob
            self.caller = caller
            self.callerDigest = digest(caller)
            self.canonicalRuleset = canonicalRuleset
            self.integrationID = integrationID
            self.population = population
            self.policyDigest = policyDigest
            self.policySource = policySource
            self.commitMessage = commitMessage
        }
    }
}
