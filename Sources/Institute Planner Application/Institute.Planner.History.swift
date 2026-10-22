public import Institute_Model

extension Institute.Planner {
    /// The publisher's main-branch commit graph. The closure is the network
    /// boundary; tests bind it to a known graph.
    public struct History: Sendable {
        public typealias Contains =
            @Sendable (
                Institute.Planner.Revision,
                Institute.Planner.Revision
            ) throws(Institute.Planner.Error) -> Swift.Bool

        public let check: Contains

        public init(_ check: @escaping Contains) {
            self.check = check
        }
    }
}

extension Institute.Planner.History {
    /// Whether `revision` is `pinned` or a descendant of it, and is itself
    /// on the publisher's main branch.
    public func contains(
        _ revision: Institute.Planner.Revision,
        atOrAfter pinned: Institute.Planner.Revision
    ) throws(Institute.Planner.Error) -> Swift.Bool {
        try check(revision, pinned)
    }
}
