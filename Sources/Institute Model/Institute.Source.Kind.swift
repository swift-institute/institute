extension Institute.Source {
    /// The kind of file a writer is about to write, and asks the rules of.
    public enum Kind: Swift.String, Swift.Sendable, Swift.Hashable, Swift.CaseIterable {
        case manifest
        case source
        case test
    }
}
