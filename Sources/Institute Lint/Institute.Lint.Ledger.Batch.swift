public import Institute_Model
public import Institute_Development

extension Institute.Lint.Ledger {
    /// A deterministic same-rule, same-owner remediation batch.
    public struct Batch: Equatable, Sendable {
        public let rule: Swift.String
        public let owner: Institute.Repository.Key
        public let issue: Swift.String
        public let repositories: [Institute.Repository.Key]
        public let findings: Swift.Int

        package init(
            rule: Swift.String,
            owner: Institute.Repository.Key,
            issue: Swift.String,
            repositories: [Institute.Repository.Key],
            findings: Swift.Int
        ) {
            self.rule = rule
            self.owner = owner
            self.issue = issue
            self.repositories = repositories.sorted(by: Institute.Repository.Key.precedes)
            self.findings = findings
        }
    }
}
