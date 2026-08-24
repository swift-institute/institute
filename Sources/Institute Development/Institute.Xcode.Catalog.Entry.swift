public import Institute_Model
public import Package_Manager
public import Source_Measurement

extension Institute.Xcode.Catalog {
    public struct Entry: Sendable {
        public let member: Institute.Workspace.Member
        public let reference: Swift.String
        public let manifest: Swift.String
        public let toolchain: Swift.String
        public let dependencies: [Swift.String]
        public let targets: [Package.Manifest.Target]
        public let sources: [Source.Artifact]

        public init(
            member: Institute.Workspace.Member,
            reference: Swift.String,
            manifest: Swift.String,
            toolchain: Swift.String,
            dependencies: [Swift.String] = [],
            targets: [Package.Manifest.Target],
            sources: [Source.Artifact]
        ) {
            self.member = member
            self.reference = reference
            self.manifest = manifest
            self.toolchain = toolchain
            self.dependencies = dependencies
            self.targets = targets
            self.sources = sources
        }
    }
}
