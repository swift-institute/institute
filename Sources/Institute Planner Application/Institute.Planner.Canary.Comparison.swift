public import Institute_Model
public import JSON

extension Institute.Planner.Canary {
    /// One canary repository measured by both planners, and every
    /// difference between the two outcomes.
    public struct Comparison: Sendable, Equatable {
        public let repository: Swift.String
        public let revision: Swift.String
        public let bundle: Swift.String
        public let current: Outcome
        public let candidate: Outcome
        public let differences: [Difference]

        public init(
            repository: Swift.String,
            revision: Swift.String,
            bundle: Swift.String,
            current: Outcome,
            candidate: Outcome
        ) {
            self.repository = repository
            self.revision = revision
            self.bundle = bundle
            self.current = current
            self.candidate = candidate
            self.differences = Self.differences(current, candidate)
        }
    }
}

extension Institute.Planner.Canary.Comparison {
    /// Whether any difference blocks adoption.
    public var isRegressed: Swift.Bool {
        differences.contains { $0.kind == .regression }
    }

    /// Every difference from `current` to `candidate`. Anything the
    /// candidate reports that the current planner did not is a regression;
    /// anything it stops reporting is an improvement.
    static func differences(
        _ current: Institute.Planner.Canary.Outcome,
        _ candidate: Institute.Planner.Canary.Outcome
    ) -> [Institute.Planner.Canary.Difference] {
        var differences: [Institute.Planner.Canary.Difference] = []
        for (planner, outcome) in [("current", current), ("candidate", candidate)]
        where outcome.status == .crashed {
            differences.append(
                .init(
                    .regression,
                    "the \(planner) planner produced no report (exit \(outcome.code.map { "\($0)" } ?? "by signal"))"
                )
            )
        }
        guard differences.isEmpty else { return differences }

        if current.status != candidate.status {
            let change = "status \(current.status.rawValue) -> \(candidate.status.rawValue)"
            switch (current.status, candidate.status) {
            case (.unmeasured, _), (.findings, .clean):
                differences.append(.init(.improvement, change))
            default:
                differences.append(.init(.regression, change))
            }
        }

        for key in Swift.Set(current.errors.keys).union(candidate.errors.keys).sorted() {
            let before = current.errors[key] ?? 0
            let after = candidate.errors[key] ?? 0
            guard before != after else { continue }
            differences.append(
                .init(after > before ? .regression : .improvement, "\(key): errors \(before) -> \(after)")
            )
        }

        let before = Swift.Set(current.unmeasured)
        let after = Swift.Set(candidate.unmeasured)
        for reason in after.subtracting(before).sorted() {
            differences.append(.init(.regression, "newly unmeasured: \(reason)"))
        }
        for reason in before.subtracting(after).sorted() {
            differences.append(.init(.improvement, "no longer unmeasured: \(reason)"))
        }

        for verdict in Swift.Set(current.controls.keys).union(candidate.controls.keys).sorted() {
            let before = current.controls[verdict] ?? 0
            let after = candidate.controls[verdict] ?? 0
            guard before != after else { continue }
            // More clean controls is better; more of any other verdict is worse.
            let worse = verdict == "clean" ? after < before : after > before
            differences.append(
                .init(worse ? .regression : .improvement, "controls \(verdict) \(before) -> \(after)")
            )
        }
        return differences
    }
}

extension Institute.Planner.Canary.Comparison: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "repository": value.repository.json,
            "revision": value.revision.json,
            "bundle": value.bundle.json,
            "current": value.current.json,
            "candidate": value.candidate.json,
            "differences": value.differences.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        let comparison = Self(
            repository: try Swift.String(json: json["repository"]),
            revision: try Swift.String(json: json["revision"]),
            bundle: try Swift.String(json: json["bundle"]),
            current: try .init(json: json["current"]),
            candidate: try .init(json: json["candidate"])
        )
        guard try [Institute.Planner.Canary.Difference](json: json["differences"])
            == comparison.differences
        else {
            throw .typeMismatch(
                expected: "differences derived from the recorded outcomes",
                got: "edited differences"
            )
        }
        return comparison
    }
}
