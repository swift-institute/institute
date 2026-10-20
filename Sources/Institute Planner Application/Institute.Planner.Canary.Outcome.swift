public import Institute_Model
public import JSON
import Source_Report

extension Institute.Planner.Canary {
    /// One planner's measurement of one canary, reduced to what the
    /// comparison reads: the overall status, the error-severity findings
    /// counted per engine and rule, every unmeasured reason, and the
    /// control-evidence verdicts counted per verdict.
    public struct Outcome: Sendable, Equatable {
        public let status: Status
        /// The planner's exit code; `nil` when a signal ended it.
        public let code: Swift.Int32?
        /// Error-severity findings per `"<engine> <rule>"`, artifact-evidence
        /// findings per `"<engine> <predicate>"`.
        public let errors: [Swift.String: Swift.Int]
        public let unmeasured: [Swift.String]
        /// Control-evidence verdicts per `clean`, `findings`, `unmeasured`.
        public let controls: [Swift.String: Swift.Int]

        public init(
            status: Status,
            code: Swift.Int32?,
            errors: [Swift.String: Swift.Int] = [:],
            unmeasured: [Swift.String] = [],
            controls: [Swift.String: Swift.Int] = [:]
        ) {
            self.status = status
            self.code = code
            self.errors = errors
            self.unmeasured = unmeasured.sorted()
            self.controls = controls
        }
    }
}

extension Institute.Planner.Canary.Outcome {
    public enum Status: Swift.String, Sendable, Equatable {
        case clean
        case findings
        case unmeasured
        /// The planner produced no readable report or exited outside the
        /// `ci -- source` exit contract.
        case crashed
    }
}

extension Institute.Planner.Canary.Outcome {
    /// Reads one `ci -- source` run: the JSON report is the standard-output
    /// line beginning `{"artifactEvidence"`.
    public init(_ execution: Institute.Planner.Canary.Execution) {
        guard let code = execution.code, (0...2).contains(code),
            let line = execution.output.split(separator: "\n").last(where: {
                $0.hasPrefix("{\"artifactEvidence\"")
            })
        else {
            self.init(status: .crashed, code: execution.code)
            return
        }
        let report: Source_Report.Source.Report
        do throws(JSON.Error) {
            report = try .init(jsonString: Swift.String(line))
        } catch {
            self.init(status: .crashed, code: code, unmeasured: ["report: \(error)"])
            return
        }
        self.init(report, code: code)
    }

    init(_ report: Source_Report.Source.Report, code: Swift.Int32) {
        let status: Status =
            switch Source_Report.Source.Report.Status(report, expected: report.commitment) {
            case .clean: .clean
            case .findings: .findings
            case .unmeasured: .unmeasured
            }
        var errors: [Swift.String: Swift.Int] = [:]
        var unmeasured: [Swift.String] = []
        var controls: [Swift.String: Swift.Int] = [:]
        do throws(Source_Report.Source.Report.Complete.Error) {
            _ = try Source_Report.Source.Report.Complete(report, expected: report.commitment)
        } catch {
            unmeasured.append("incomplete report: \(error)")
        }
        for measurement in report.measurements {
            switch measurement.verdict {
            case .clean, .notRequested:
                break
            case .findings(let findings):
                for finding in findings where finding.diagnostic.severity == .error {
                    errors["\(measurement.engine.token) \(finding.rule.token)", default: 0] += 1
                }
            case .unmeasured(let reasons):
                for reason in reasons {
                    unmeasured.append("\(measurement.engine.token): \(reason.code): \(reason.detail)")
                }
            }
        }
        for evidence in report.artifactEvidence {
            switch evidence.verdict {
            case .clean:
                break
            case .findings(let reasons):
                errors[
                    "\(evidence.predicate.engine.token) \(evidence.predicate.token)",
                    default: 0
                ] += reasons.count
            case .unmeasured(let reasons):
                for reason in reasons {
                    unmeasured.append("\(evidence.artifact.path): \(reason.code): \(reason.detail)")
                }
            }
        }
        for evidence in report.controlEvidence {
            switch evidence.verdict {
            case .clean:
                controls["clean", default: 0] += 1
            case .findings:
                controls["findings", default: 0] += 1
            case .unmeasured(let reasons):
                controls["unmeasured", default: 0] += 1
                for reason in reasons {
                    unmeasured.append("control \(evidence.identity): \(reason.code): \(reason.detail)")
                }
            }
        }
        self.init(
            status: status,
            code: code,
            errors: errors,
            unmeasured: unmeasured,
            controls: controls
        )
    }
}

extension Institute.Planner.Canary.Outcome: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "status": value.status.rawValue.json,
            "exit": value.code.map { Swift.Int($0).json } ?? .null,
            "errors": .object(value.errors.sorted { $0.key < $1.key }.map { ($0.key, $0.value.json) }),
            "unmeasured": value.unmeasured.json,
            "controls": .object(value.controls.sorted { $0.key < $1.key }.map { ($0.key, $0.value.json) }),
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let status = Status(rawValue: try Swift.String(json: json["status"])) else {
            throw .typeMismatch(expected: "canary status", got: "other")
        }
        var code: Swift.Int32? = nil
        if !json["exit"].isNull {
            guard let exact = Swift.Int32(exactly: try Swift.Int(json: json["exit"])) else {
                throw .typeMismatch(expected: "32-bit exit code", got: "other")
            }
            code = exact
        }
        return .init(
            status: status,
            code: code,
            errors: try counts(json["errors"]),
            unmeasured: try [Swift.String](json: json["unmeasured"]),
            controls: try counts(json["controls"])
        )
    }

    private static func counts(_ json: JSON) throws(JSON.Error) -> [Swift.String: Swift.Int] {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object of counts", got: "other")
        }
        var counts: [Swift.String: Swift.Int] = [:]
        for (key, value) in object {
            counts[key] = try Swift.Int(json: value)
        }
        return counts
    }
}
