public import File_System
public import Git_Foundation
public import Institute_Model

extension Institute.Checkout {
    /// One completed exact materialization: the verified identity of what
    /// was published, and where.
    ///
    /// `revision` and `tree` are the canonical evidence — two
    /// materializations of the same commit at different destinations agree
    /// on both. `directory` is machine-local working state for the process
    /// that requested the checkout; it identifies a path, not the source,
    /// and must never enter content-addressed evidence.
    public struct Materialized: Equatable, Sendable {
        public let revision: Git.Object.ID
        public let tree: Git.Object.ID
        public let directory: File.Directory

        public init(
            revision: Git.Object.ID,
            tree: Git.Object.ID,
            directory: File.Directory
        ) {
            self.revision = revision
            self.tree = tree
            self.directory = directory
        }
    }
}
