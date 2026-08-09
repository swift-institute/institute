public import Institute_Model
public import Institute_Development

extension Institute.Lint.Ledger {
    /// One advisory rule class present in one repository.
    public struct Advisory: Equatable, Sendable {
        public let rule: Swift.String
        public let findings: [Institute.Lint.Finding]
        public let disposition: Disposition?

        public init(
            rule: Swift.String,
            findings: [Institute.Lint.Finding],
            disposition: Disposition?
        ) {
            self.rule = rule
            self.findings = findings.sorted(by: Institute.Lint.Finding.precedes)
            self.disposition = disposition
        }
    }
}
