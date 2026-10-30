public import Institute_Model

extension Institute.Version {
    /// Whether one commit passed the Institute's CI on `main`.
    ///
    /// Only `ci-ok`, the single required status check, counts, and only
    /// from a run of the generated caller on `main` (a push or a dispatch),
    /// where the aggregate already refuses anything below the full tier. A
    /// pull-request run of the same commit does not count.
    public enum Gate: Swift.Hashable, Swift.Sendable {
        /// A `main` run's latest `ci-ok` for the commit succeeded.
        case passed
        /// A `main` run for the commit has not finished.
        case pending
        /// Every `main` run for the commit finished, and none passed;
        /// carries the latest `ci-ok` conclusion.
        case failed(Swift.String)
        /// No `main` run of the generated caller exists for the commit.
        case absent
    }
}

extension Institute.Version.Gate {
    /// The workflow file every package's generated caller lives in.
    public static let workflow = ".github/workflows/ci.yml"
    /// The check name of `ci-ok` as the generated caller's `ci / matrix`
    /// job reports it.
    public static let check = "ci / matrix / ci-ok"
    /// The events whose runs on `main` attest a commit.
    public static let events: Swift.Set<Swift.String> = ["push", "workflow_dispatch"]

    /// One workflow run for the commit.
    public struct Run: Swift.Hashable, Swift.Sendable {
        public let suite: Swift.Int
        public let event: Swift.String
        public let branch: Swift.String
        public let path: Swift.String
        public let completed: Swift.Bool

        public init(
            suite: Swift.Int,
            event: Swift.String,
            branch: Swift.String,
            path: Swift.String,
            completed: Swift.Bool
        ) {
            self.suite = suite
            self.event = event
            self.branch = branch
            self.path = path
            self.completed = completed
        }
    }

    /// The latest `ci-ok` check run of one check suite.
    public struct Check: Swift.Hashable, Swift.Sendable {
        public let suite: Swift.Int
        public let completed: Swift.Bool
        /// The conclusion of a completed check; nil while it runs.
        public let conclusion: Swift.String?

        public init(suite: Swift.Int, completed: Swift.Bool, conclusion: Swift.String?) {
            self.suite = suite
            self.completed = completed
            self.conclusion = conclusion
        }
    }

    /// Judges a commit from its workflow runs and its `ci-ok` checks.
    ///
    /// Any successful `ci-ok` of a `main` run passes the commit: a later
    /// failed re-run of the same commit does not revoke what was attested.
    /// Checks of any other run, such as a pull request's, are ignored.
    public init(runs: [Run], checks: [Check]) {
        let suites = Swift.Set(
            runs.filter {
                $0.path == Self.workflow && $0.branch == "main" && Self.events.contains($0.event)
            }
            .map(\.suite)
        )
        let attesting = checks.filter { suites.contains($0.suite) }
        if attesting.contains(where: { $0.completed && $0.conclusion == "success" }) {
            self = .passed
        } else if attesting.contains(where: { !$0.completed })
            || runs.contains(where: { suites.contains($0.suite) && !$0.completed })
        {
            self = .pending
        } else if let concluded = attesting.last(where: \.completed) {
            self = .failed(concluded.conclusion ?? "unknown")
        } else if suites.isEmpty {
            self = .absent
        } else {
            self = .failed("no \(Self.check) check")
        }
    }
}
