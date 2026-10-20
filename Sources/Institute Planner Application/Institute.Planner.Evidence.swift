public import Institute_Model
public import JSON

extension Institute.Planner {
    /// The canary's record: which publish run and revision it judged, the
    /// two binaries it ran, every canary comparison, and the verdict.
    /// `adopt` admits only an adoptable record for its own publish run.
    public struct Evidence: Sendable, Equatable {
        public static let schema = 1

        public let verdict: Canary.Verdict
        public let run: Swift.String
        /// The candidate revision; empty when the publication was refused
        /// before its revision was known.
        public let revision: Swift.String
        /// The candidate's verified PIN lines, verbatim.
        public let rows: [Swift.String]
        public let candidate: Binary?
        public let current: Binary?
        public let xcode: Swift.String
        public let repositories: [Canary.Comparison]
        /// Why the canary refused; empty unless the verdict is refused.
        public let refusal: Swift.String

        public init(
            verdict: Canary.Verdict,
            run: Swift.String,
            revision: Swift.String = "",
            rows: [Swift.String] = [],
            candidate: Binary? = nil,
            current: Binary? = nil,
            xcode: Swift.String = "",
            repositories: [Canary.Comparison] = [],
            refusal: Swift.String = ""
        ) {
            self.verdict = verdict
            self.run = run
            self.revision = revision
            self.rows = rows
            self.candidate = candidate
            self.current = current
            self.xcode = xcode
            self.repositories = repositories
            self.refusal = refusal
        }
    }
}

extension Institute.Planner.Evidence {
    /// The evidence of a canary that compared `repositories`; its verdict
    /// follows from the comparisons.
    public init(
        run: Swift.String,
        candidate: Institute.Planner.Executable,
        current: Institute.Planner.Executable,
        rows: [Institute.Planner.Row],
        xcode: Swift.String,
        repositories: [Institute.Planner.Canary.Comparison]
    ) {
        self.init(
            verdict: .init(repositories),
            run: run,
            revision: candidate.row.revision.description,
            rows: rows.map(\.line),
            candidate: .init(candidate),
            current: .init(current),
            xcode: xcode,
            repositories: repositories
        )
    }

    /// The evidence of a canary that refused.
    public init(run: Swift.String, refusal: Institute.Planner.Error) {
        self.init(verdict: .refused, run: run, refusal: refusal.description)
    }

    /// One line per canary for the commit message and the human table.
    public var summary: [Swift.String] {
        repositories.map { comparison in
            let errors = { (outcome: Institute.Planner.Canary.Outcome) in
                outcome.errors.values.reduce(0, +)
            }
            let regressions = comparison.differences.count(where: { $0.kind == .regression })
            let improvements = comparison.differences.count(where: { $0.kind == .improvement })
            return "\(comparison.repository): \(comparison.current.status.rawValue) -> "
                + "\(comparison.candidate.status.rawValue), errors \(errors(comparison.current)) -> "
                + "\(errors(comparison.candidate)), \(regressions) regressions, \(improvements) improvements"
        }
    }
}

extension Institute.Planner.Evidence: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "schema": schema.json,
            "verdict": value.verdict.rawValue.json,
            "publishRun": value.run.json,
            "revision": value.revision.json,
            "rows": value.rows.json,
            "candidate": value.candidate?.json ?? .null,
            "current": value.current?.json ?? .null,
            "xcodeApplication": value.xcode.json,
            "repositories": value.repositories.json,
            "refusal": value.refusal.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard try Swift.Int(json: json["schema"]) == schema else {
            throw .typeMismatch(expected: "planner evidence schema \(schema)", got: "other schema")
        }
        guard let verdict = Institute.Planner.Canary.Verdict(
            rawValue: try Swift.String(json: json["verdict"])
        ) else {
            throw .typeMismatch(expected: "adoptable, differs or refused", got: "other verdict")
        }
        let repositories = try [Institute.Planner.Canary.Comparison](json: json["repositories"])
        // A recorded verdict must be the one its comparisons give, so an
        // edited verdict cannot turn a differing canary adoptable.
        guard verdict == .refused || verdict == .init(repositories) else {
            throw .typeMismatch(
                expected: "the verdict the comparisons give",
                got: verdict.rawValue
            )
        }
        return .init(
            verdict: verdict,
            run: try Swift.String(json: json["publishRun"]),
            revision: try Swift.String(json: json["revision"]),
            rows: try [Swift.String](json: json["rows"]),
            candidate: try json["candidate"].isNull ? nil : Binary(json: json["candidate"]),
            current: try json["current"].isNull ? nil : Binary(json: json["current"]),
            xcode: try Swift.String(json: json["xcodeApplication"]),
            repositories: repositories,
            refusal: try Swift.String(json: json["refusal"])
        )
    }
}
