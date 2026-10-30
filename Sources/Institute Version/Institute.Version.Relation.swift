public import Institute_Model

extension Institute.Version {
    /// Where a head commit stands relative to a base commit, as GitHub's
    /// compare reports it.
    public enum Relation: Swift.String, Swift.Hashable, Swift.Sendable {
        /// The head strictly descends from the base.
        case ahead
        /// The head and the base are one commit.
        case identical
        /// The head is an ancestor of the base.
        case behind
        /// Neither descends from the other.
        case diverged
    }
}
