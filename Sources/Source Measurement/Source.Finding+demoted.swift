extension Source.Finding {
    /// This finding at warning severity; every other field is unchanged.
    public var demoted: Self {
        .init(
            rule: rule,
            diagnostic: .init(
                location: diagnostic.location,
                severity: .warning,
                identifier: diagnostic.identifier,
                message: diagnostic.message
            ),
            repair: repair
        )
    }
}

extension Source.Measurement {
    /// This measurement with the error findings selected by `predicate`
    /// reported as warnings.
    ///
    /// Warnings are reported and never fail a strict run, so demotion changes
    /// what a rule costs in a place without changing what the rule sees.
    public func demotingFindings(
        where predicate: (Source.Finding) -> Swift.Bool
    ) -> Self {
        guard case .findings(let findings) = verdict else { return self }
        return .init(
            engine: engine,
            subject: subject,
            activeRules: activeRules,
            applicableRules: applicableRules,
            files: files,
            observations: observations,
            suppressions: suppressions,
            repairs: repairs,
            controls: controls,
            verdict: .findings(
                findings.map { $0.diagnostic.severity == .error && predicate($0) ? $0.demoted : $0 }
            )
        )
    }
}
