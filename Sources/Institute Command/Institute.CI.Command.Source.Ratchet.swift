import Institute_CI_Model
import Institute_Model
import Source_Report

extension Institute.CI.Command.Source {
    /// How many findings of each swift-linter rule a repository may have. A
    /// strict run fails when any rule goes over its limit, so warnings that
    /// never fail on their own can't grow.
    ///
    /// A repository or rule not listed may have none. Limits are regenerated
    /// by `ratchet.py` in swift-institute/cloud-workspace, which refuses a rise
    /// in a rule's total, so the table ships with the rules it was measured by.
    enum Ratchet {
        static let engine = "swift-linter"

        /// The swift-linter findings in `report`, by rule.
        static func counts(_ report: Source_Report::Source.Report) -> [Swift.String: Swift.Int] {
            var counts: [Swift.String: Swift.Int] = [:]
            for measurement in report.measurements where measurement.engine.token == engine {
                guard case .findings(let findings) = measurement.verdict else { continue }
                for finding in findings {
                    counts[finding.rule.token, default: 0] += 1
                }
            }
            return counts
        }

        /// One line for each rule in `counts` over its limit in `table`, sorted by rule.
        static func overruns(
            repository: Swift.String,
            counts: [Swift.String: Swift.Int],
            table: Swift.String = limits
        ) -> [Swift.String] {
            let allowed = Self.allowed(for: repository, in: table)
            return counts.keys.sorted().compactMap { rule in
                let count = counts[rule] ?? 0
                let limit = allowed[rule] ?? 0
                guard count > limit else { return nil }
                return "ratchet: \(repository) has \(count) `\(rule)` findings, limit \(limit). Fix them; a limit doesn't rise."
            }
        }

        /// `repository`'s limits from `table`, whose lines are `owner/name|rule|limit`.
        static func allowed(for repository: Swift.String, in table: Swift.String) -> [Swift.String: Swift.Int] {
            var allowed: [Swift.String: Swift.Int] = [:]
            for line in table.split(separator: "\n") {
                let fields = line.split(separator: "|", omittingEmptySubsequences: false)
                guard fields.count == 3, fields[0] == repository, let limit = Swift.Int(fields[2]) else { continue }
                allowed[Swift.String(fields[1])] = limit
            }
            return allowed
        }
    }
}
