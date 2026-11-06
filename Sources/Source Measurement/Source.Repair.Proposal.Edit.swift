public import Path

extension Source.Repair.Proposal {
    public struct Edit: Hashable, Sendable {
        public let path: Path::Path
        public let expected: Swift.String
        public let replacement: [UInt8]

        public init(path: Path::Path, expected: Swift.String, replacement: [UInt8]) {
            self.path = path
            self.expected = expected
            self.replacement = replacement
        }
    }
}
