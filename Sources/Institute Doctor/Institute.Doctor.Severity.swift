internal import Institute_Development
internal import Institute_Inventory
internal import Institute_Lint
public import Institute_Model
internal import Institute_Pages

extension Institute.Doctor {
    /// How serious a measured finding is.
    ///
    /// `warning` findings are advisory: they are reported but do not fail
    /// the run. `error` findings contribute exit code 1.
    public enum Severity: Comparable, Equatable, Sendable {
        case warning
        case error
    }
}

extension Institute.Doctor.Severity: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .warning: "warning"
        case .error: "error"
        }
    }
}
