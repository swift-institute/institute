public import Institute_Model

extension Institute.Composition {
    /// Which repositories one composition covers.
    ///
    /// Exactly two forms exist: the full inventory, and explicit seeds
    /// normalized to their complete forward Institute dependency
    /// closure. No layer, family, path-prefix, changed-file, or
    /// reverse-dependency selector is admitted — a selector vocabulary
    /// would be a second spelling of the inventory owner's roster.
    public enum Scope: Swift.Equatable, Swift.Sendable {
        /// Every repository the inventory owner admits.
        case inventory

        /// The named repositories plus every Institute repository their
        /// evaluated manifests reach, transitively.
        ///
        /// Seeds are inventory references (repository names), validated
        /// against the roster during normalization — an unknown seed is
        /// a typed error, never a silent skip.
        case seeds([Swift.String])
    }
}
