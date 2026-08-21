public import Institute_Model
public import Source_Measurement
public import Xcode_Workspace

extension Institute.Source.Workspace {
    public struct Row: Sendable {
        public let index: Swift.Int
        public let location: Xcode.Workspace.Location
        public let directory: Swift.String
        public let identity: Swift.String
        public let role: Institute.Workspace.Role
        public let repository: Institute.Repository?
        public let reason: Source_Measurement.Source.Reason?

        public init(
            index: Swift.Int,
            location: Xcode.Workspace.Location,
            directory: Swift.String,
            identity: Swift.String,
            role: Institute.Workspace.Role,
            repository: Institute.Repository?,
            reason: Source_Measurement.Source.Reason?
        ) {
            self.index = index
            self.location = location
            self.directory = directory
            self.identity = identity
            self.role = role
            self.repository = repository
            self.reason = reason
        }
    }
}
