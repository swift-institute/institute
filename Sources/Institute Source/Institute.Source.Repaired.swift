public import Institute_Model

extension Institute.Source {
    /// What one repair of a package did.
    public struct Repaired: Sendable, Equatable {
        /// The files rewritten, relative to the package root, sorted.
        public let rewritten: [Swift.String]
        /// The files with repairable findings that were left as they were,
        /// each with the reason, sorted by file.
        public let declined: [Declined]

        public init(rewritten: [Swift.String], declined: [Declined]) {
            self.rewritten = rewritten.sorted()
            self.declined = declined.sorted { ($0.file, $0.reason) < ($1.file, $1.reason) }
        }
    }
}
