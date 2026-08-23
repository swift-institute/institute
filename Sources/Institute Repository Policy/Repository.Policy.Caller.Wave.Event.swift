extension Repository.Policy.Caller.Wave {
    public struct Event: Codable, Sendable, Equatable {
        public let phase: String
        public let repository: String
        public let oldHead: String?
        public let newHead: String?
        public let oldBlob: String?
        public let newBlob: String?
        public let ruleset: Int64?
        public let bypassClosed: Bool?
        public let populationDigest: String?
        public let policyDigest: String?
        public let policySource: String?

        public init(
            phase: String,
            repository: String,
            oldHead: String? = nil,
            newHead: String? = nil,
            oldBlob: String? = nil,
            newBlob: String? = nil,
            ruleset: Int64? = nil,
            bypassClosed: Bool? = nil,
            populationDigest: String? = nil,
            policyDigest: String? = nil,
            policySource: String? = nil
        ) {
            self.phase = phase
            self.repository = repository
            self.oldHead = oldHead
            self.newHead = newHead
            self.oldBlob = oldBlob
            self.newBlob = newBlob
            self.ruleset = ruleset
            self.bypassClosed = bypassClosed
            self.populationDigest = populationDigest
            self.policyDigest = policyDigest
            self.policySource = policySource
        }
    }
}
