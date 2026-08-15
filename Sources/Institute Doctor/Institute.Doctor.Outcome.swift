public import Institute_Development
public import Institute_Inventory
public import Institute_Lint
public import Institute_Model
public import Institute_Pages

extension Institute.Doctor {
    /// The result of one check in one run, with the findings it measured.
    ///
    /// `findings` is non-empty exactly when `result` is
    /// ``Institute/Doctor/Result/finding(severity:population:)``.
    public struct Outcome: Equatable, Sendable {
        public let check: Swift.String
        public let scope: Scope
        public let result: Result
        public let findings: [Finding]

        public init(
            check: Swift.String,
            scope: Scope,
            result: Result,
            findings: [Finding]
        ) {
            self.check = check
            self.scope = scope
            self.result = result
            self.findings = findings
        }
    }
}
