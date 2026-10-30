public import Institute_Model

extension Institute.Version {
    /// One tag of a repository and the commit it names. An annotated tag is
    /// read through to its commit.
    public struct Tag: Swift.Hashable, Swift.Sendable {
        public let name: Swift.String
        public let commit: Swift.String

        public init(name: Swift.String, commit: Swift.String) {
            self.name = name
            self.commit = commit
        }
    }
}
