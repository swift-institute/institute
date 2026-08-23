public import Institute_Model
public import JSON

extension Institute.Repository.Policy.Caller.Wave {
    /// A typed record of one successful GitHub App installation-token issuance,
    /// written by the protected host only after the official token action
    /// succeeded. The issuance response is the authoritative write-capability
    /// evidence for an App installation; collaborator-style repository
    /// permission booleans are not.
    public struct Attestation: Sendable, Equatable {
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

extension Institute.Repository.Policy.Caller.Wave.Attestation: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "appClientID": value.appClientID.json,
            "appSlug": value.appSlug.json,
            "installationID": value.installationID.json,
            "organization": value.organization.json,
            "repositories": value.repositories.json,
            "permissions": value.permissions.json,
            "runID": value.runID.json,
            "issuedAt": value.issuedAt.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            appClientID: try Swift.String(json: json["appClientID"]),
            appSlug: try Swift.String(json: json["appSlug"]),
            installationID: try Swift.Int64(json: json["installationID"]),
            organization: try Swift.String(json: json["organization"]),
            repositories: try [Swift.String](json: json["repositories"]),
            permissions: try [Swift.String: Swift.String](json: json["permissions"]),
            runID: try Swift.Int64(json: json["runID"]),
            issuedAt: try Swift.String(json: json["issuedAt"])
        )
    }
}
