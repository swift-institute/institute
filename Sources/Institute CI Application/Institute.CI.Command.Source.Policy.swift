public import Institute_CI_Model
public import Institute_Model
public import Source_Report

extension Institute.CI.Command.Source {
    public enum Policy: Swift.String, Sendable, CaseIterable {
        case advisory
        case strict

        public func code(
            status: Source_Report.Source.Report.Status,
            errors: Swift.Bool
        ) -> Swift.Int32 {
            switch (status, self) {
            case (.unmeasured, _): status.code
            case (_, .advisory): Source_Report.Source.Report.Status.clean.code
            case (_, .strict): errors ? Source_Report.Source.Report.Status.findings.code : Source_Report.Source.Report.Status.clean.code
            }
        }

        public static func errors(in report: Source_Report.Source.Report) -> Swift.Bool {
            report.measurements.contains { measurement in
                guard case .findings(let findings) = measurement.verdict else { return false }
                return findings.contains { $0.diagnostic.severity == .error }
            }
                || report.artifactEvidence.contains { evidence in
                    if case .findings = evidence.verdict { true } else { false }
                }
                || report.controlEvidence.contains { evidence in
                    if case .findings = evidence.verdict { true } else { false }
                }
        }
    }
}
