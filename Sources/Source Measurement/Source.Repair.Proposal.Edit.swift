extension Source.Repair.Proposal {
    public struct Edit: Hashable, Sendable {
        public let path: Swift.String
        public let expected: Swift.String
        public let replacement: [UInt8]

        public init(path: Swift.String, expected: Swift.String, replacement: [UInt8]) {
            self.path = path
            self.expected = expected
            self.replacement = replacement
        }
    }
}
