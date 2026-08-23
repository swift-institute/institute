extension Repository.Policy.Uniformity {
    /// The bounded forward transaction that converges one package
    /// repository onto the ratified canonical shape policy: root
    /// `.gitignore` becomes the exact ratified bytes and the retired
    /// per-repository configuration files (`.swiftlint.yml`,
    /// `.swift-format`, `.github/dependabot.yml`) are deleted.
    ///
    /// The family reuses the caller wave's debugged primitives — client
    /// error domain, ruleset bypass open/close, expected-head guards,
    /// head-convergence polling, and the recovery/closure/recensus
    /// patterns — rather than growing second copies.
    public enum Wave {
        public typealias Error = Repository.Policy.Caller.Wave.Error
        public typealias Manifest = Repository.Policy.Caller.Wave.Manifest
        public typealias Commitment = Repository.Policy.Caller.Wave.Commitment
        public typealias Attestation = Repository.Policy.Caller.Wave.Attestation
        public typealias RulesetReference = Repository.Policy.Caller.Wave.RulesetReference
        public typealias RulesetSnapshot = Repository.Policy.Caller.Wave.RulesetSnapshot
        public typealias OrganizationExclusion =
            Repository.Policy.Caller.Wave.Population.OrganizationExclusion
    }
}
