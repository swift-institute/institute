public import Institute_Model

extension Institute.Planner.Canary {
    /// The canary's process boundary: shallow-cloning a repository's
    /// default-branch head, and running a planner binary. Tests bind both
    /// to fixtures.
    public struct Runner: Sendable {
        /// Clones `remote`'s default-branch head into `directory` and
        /// returns the revision checked out.
        public typealias Clone =
            @Sendable (_ remote: Swift.String, _ directory: Swift.String) throws(Institute.Planner.Error)
            -> Institute.Planner.Revision
        /// Runs `executable` with `arguments`, capturing standard output.
        public typealias Execute =
            @Sendable (_ executable: Swift.String, _ arguments: [Swift.String]) throws(Institute.Planner.Error)
            -> Execution

        public let clone: Clone
        public let execute: Execute

        public init(clone: @escaping Clone, execute: @escaping Execute) {
            self.clone = clone
            self.execute = execute
        }
    }
}
