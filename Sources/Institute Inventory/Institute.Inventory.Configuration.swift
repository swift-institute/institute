public import Async_Fanout
public import Institute_Model

extension Institute.Inventory {
    /// What one run reads, where it writes, and how wide it fans out.
    public struct Configuration: Sendable {
        /// An absolute directory.
        public var root: Swift.String
        /// The directory the tables are written into; created when missing.
        public var output: Swift.String
        /// Path prefixes relative to the root that are not walked.
        public var excluded: [Swift.String]
        /// How many manifests are evaluated, and files parsed, at once.
        public var fanout: Async.Fanout

        public init(
            root: Swift.String,
            output: Swift.String,
            excluded: [Swift.String] = [],
            fanout: Async.Fanout = .init()
        ) {
            self.root = root.count > 1 && root.hasSuffix("/") ? Swift.String(root.dropLast()) : root
            self.output = output
            self.excluded = excluded
            self.fanout = fanout
        }
    }
}
