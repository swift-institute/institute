public import Institute_Model

extension Institute.Version {
    /// What the sweep did, or in a dry run would do, for one repository.
    public enum Outcome: Swift.Hashable, Swift.Sendable {
        /// The tag was created on the head of `main`.
        case tagged(Tag)
        /// A dry run: the tag a real run would create.
        case planned(Tag)
        /// The head of `main` already carries this tag of the line.
        case current(Tag)
        /// Backfill only: the repository is already on the line, so the
        /// backfill leaves it to the continuous sweep. Carries the line's
        /// latest tag.
        case versioned(Tag)
        /// The repository is not tagged by design.
        case skipped(Skip)
        /// The head's CI has not reached a verdict, or has no `main` run.
        case waiting(Gate)
        /// The head's `ci-ok` on `main` did not pass; carries its conclusion.
        case held(Swift.String)
        /// The head does not descend from the line's latest tag, so no
        /// next version can be ordered after it. Needs a person.
        case refused(latest: Tag, relation: Relation)
        /// Another writer created the tag's name for a different commit
        /// between this sweep's read and its write; the next sweep orders
        /// after it.
        case contended(Tag, existing: Swift.String)
        /// A read or the write failed.
        case failed(Error)
    }
}

extension Institute.Version.Outcome {
    /// Why a repository is not tagged by design.
    public enum Skip: Swift.String, Swift.Hashable, Swift.Sendable {
        case archived
        case `private`
        /// The repository has no `main` branch.
        case unbranched
    }

    /// Whether the outcome needs a person: a refusal or a failure. Waiting
    /// for CI, a red `main` and a lost race resolve themselves.
    public var blocking: Swift.Bool {
        switch self {
        case .refused, .failed: true
        case .tagged, .planned, .current, .versioned, .skipped, .waiting, .held, .contended: false
        }
    }
}

extension Institute.Version {
    /// One repository's outcome and the head of `main` it was judged at.
    public struct Report: Swift.Hashable, Swift.Sendable {
        public let repository: Institute.Repository.Coordinate
        public let head: Swift.String?
        public let outcome: Outcome

        public init(repository: Institute.Repository.Coordinate, head: Swift.String?, outcome: Outcome) {
            self.repository = repository
            self.head = head
            self.outcome = outcome
        }
    }
}
