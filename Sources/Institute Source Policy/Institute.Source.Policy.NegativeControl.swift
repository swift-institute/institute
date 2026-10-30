public import Institute_Model
public import Source_Profile

extension Institute.Source.Policy {
    /// A fixture that violates one rule on purpose, declared so that the
    /// violation is evidence rather than a finding.
    ///
    /// A rule's failing fixture has to stay failing: it is what proves the
    /// rule still fires. Measured as governed source it is a permanent
    /// error that the repository cannot fix without destroying the proof.
    /// Declared here it leaves governed source — no engine measures it for
    /// Quality — and becomes a control of its rule instead: the rule's
    /// engine measures it on its own, and Quality fails unless the rule
    /// reports exactly `findings` findings in it. A fixture that stops
    /// tripping its rule, or trips it a different number of times, is a
    /// failed control, never a silently clean file.
    public struct NegativeControl: Hashable, Sendable {
        /// The owning repository, `owner/name`.
        public let repository: Swift.String
        /// The fixture's path relative to the repository root.
        public let path: Swift.String
        /// The rule the fixture violates.
        public let rule: Source.Rule.ID
        /// How many findings of `rule` the fixture must produce; at least one.
        public let findings: Swift.Int

        public init(
            repository: Swift.String,
            path: Swift.String,
            rule: Source.Rule.ID,
            findings: Swift.Int = 1
        ) {
            precondition(findings > 0, "a negative control must expect at least one finding")
            self.repository = repository
            self.path = path
            self.rule = rule
            self.findings = findings
        }

        /// The control identity, unique across the fleet.
        public var identity: Swift.String { "\(repository):\(path)" }
    }

    /// The negative controls declared for `repository`, keyed by path.
    public func negativeControls(
        for repository: Swift.String
    ) -> [Swift.String: NegativeControl] {
        var controls: [Swift.String: NegativeControl] = [:]
        for control in negativeControls where control.repository == repository {
            controls[control.path] = control
        }
        return controls
    }
}
