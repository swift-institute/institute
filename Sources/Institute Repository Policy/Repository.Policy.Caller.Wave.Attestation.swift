extension Repository.Policy.Caller.Wave {
    /// A typed record of one successful GitHub App installation-token issuance,
    /// written by the protected host only after the official token action
    /// succeeded. The issuance response is the authoritative write-capability
    /// evidence for an App installation; collaborator-style repository
    /// permission booleans are not.
    public struct Attestation: Codable, Sendable, Equatable {
        public let appClientID: String
        public let appSlug: String
        public let installationID: Int64
        public let organization: String
        public let repositories: [String]
        public let permissions: [String: String]
        public let runID: Int64
        public let issuedAt: String

        public init(
            appClientID: String,
            appSlug: String,
            installationID: Int64,
            organization: String,
            repositories: [String],
            permissions: [String: String],
            runID: Int64,
            issuedAt: String
        ) {
            self.appClientID = appClientID
            self.appSlug = appSlug
            self.installationID = installationID
            self.organization = organization
            self.repositories = repositories
            self.permissions = permissions
            self.runID = runID
            self.issuedAt = issuedAt
        }
    }
}
