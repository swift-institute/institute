public import Institute_Model
public import Source_Profile

extension Institute.Source.Policy {
    public struct Engine: Sendable {
        public let id: Source_Profile.Source.Engine.ID
        public let platform: Platform
        public let version: Swift.String
        public let revision: Swift.String
        public let toolchain: Swift.String
        public let schema: Swift.String
        public let executable: Asset
        public let manifest: Asset?
        public let inventory: Asset?
        public let checksums: Asset?

        public init(
            id: Source_Profile.Source.Engine.ID,
            platform: Platform,
            version: Swift.String,
            revision: Swift.String,
            toolchain: Swift.String,
            schema: Swift.String,
            executable: Asset,
            manifest: Asset?,
            inventory: Asset?,
            checksums: Asset?
        ) {
            precondition(!version.isEmpty)
            precondition(!revision.isEmpty)
            precondition(!toolchain.isEmpty)
            precondition(!schema.isEmpty)
            precondition((manifest == nil) == (inventory == nil))
            precondition((manifest == nil) == (checksums == nil))
            self.id = id
            self.platform = platform
            self.version = version
            self.revision = revision
            self.toolchain = toolchain
            self.schema = schema
            self.executable = executable
            self.manifest = manifest
            self.inventory = inventory
            self.checksums = checksums
        }
    }
}
