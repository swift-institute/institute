extension Source.Report {
    /// Whether the report carries anything the strict exit policy fails on:
    /// an error-severity engine finding, or any artifact or control finding.
    ///
    /// Warning-severity engine findings are reported and never fail a strict
    /// run.
    public var errors: Swift.Bool {
        measurements.contains { measurement in
            guard case .findings(let findings) = measurement.verdict else { return false }
            return findings.contains { $0.diagnostic.severity == .error }
        }
            || artifactEvidence.contains { evidence in
                if case .findings = evidence.verdict { true } else { false }
            }
            || controlEvidence.contains { evidence in
                if case .findings = evidence.verdict { true } else { false }
            }
    }
}
