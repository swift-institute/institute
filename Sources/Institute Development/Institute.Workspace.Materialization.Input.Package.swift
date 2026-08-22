public import Institute_Model
public import JSON
public import Source_Measurement

extension Institute.Workspace.Materialization.Input {
    public struct Package: Sendable, Equatable, JSON.Serializable {
        public let member: Institute.Workspace.Member
        public let reference: Swift.String
        public let manifest: Swift.String
        public let sources: [Source.Artifact]

        public init(
            member: Institute.Workspace.Member,
            reference: Swift.String,
            manifest: Swift.String,
            sources: [Source.Artifact]
        ) {
            self.member = member
            self.reference = reference
            self.manifest = manifest
            self.sources = sources
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "member": value.member.json,
                "reference": value.reference.json,
                "manifest": value.manifest.json,
                "sources": value.sources.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            try .init(
                member: Institute.Workspace.Member(json: json["member"]),
                reference: Swift.String(json: json["reference"]),
                manifest: Swift.String(json: json["manifest"]),
                sources: [Source.Artifact](json: json["sources"])
            )
        }
    }
}
