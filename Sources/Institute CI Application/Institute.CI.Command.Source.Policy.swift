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
    }
}
