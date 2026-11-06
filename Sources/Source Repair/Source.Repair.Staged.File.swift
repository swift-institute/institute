public import Path

extension Source.Repair.Staged {
    public struct File: Hashable, Sendable {
        public let path: Path::Path
        public let contents: [UInt8]?

        public init(path: Path::Path, contents: [UInt8]?) {
            self.path = path
            self.contents = contents
        }
    }
}
