extension RepositoryPolicy.Fleet {
    public struct Organization: Swift.Decodable, Swift.Sendable, Swift.Equatable {
        public let name: Swift.String
        public let layer: Swift.String
        public let status: Swift.String
    }
}
