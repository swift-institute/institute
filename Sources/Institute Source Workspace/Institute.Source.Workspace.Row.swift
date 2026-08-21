extension Institute.Source.Workspace {
    public struct Row: Sendable {
        public let index: Swift.Int
        public let location: Xcode.Workspace.Location
        public let directory: Swift.String
        public let identity: Swift.String
        public let repository: Institute.Repository?
        public let reason: SourceDomain.Reason?

        public init(
            index: Swift.Int,
            location: Xcode.Workspace.Location,
            directory: Swift.String,
            identity: Swift.String,
            repository: Institute.Repository?,
            reason: SourceDomain.Reason?
        ) {
            self.index = index
            self.location = location
            self.directory = directory
            self.identity = identity
            self.repository = repository
            self.reason = reason
        }
    }
}
