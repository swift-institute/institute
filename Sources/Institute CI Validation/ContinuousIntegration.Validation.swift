import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import ContinuousIntegration

// Nest.Name namespace shell (FT1-ratification.json;
// naming-annex-nest-name.md).
//
// `ContinuousIntegration.Validation` owns the Institute's
// *policy* validators — the corpus-and-convention predicates (skill
// hygiene, gitignore canon, README conventions, schema correspondence,
// manifest binding) that are Institute doctrine rather than GitHub
// Actions mechanics. The validator *contract* — what a rule is, what it
// is run against, what it emits, and how an implementation is proved —
// is owned by `GitHub.ContinuousIntegration.Validation` in
// swift-foundations/swift-github-continuous-integration; this nest
// re-exports that contract so an Institute validator reads the same as
// it did in the shared registry.
//
// A rule implementation declares a `Validator`; it never prints, never
// exits, and never reads argv.
extension ContinuousIntegration {
    public enum Validation {}
}

extension ContinuousIntegration.Validation {
    /// The validator contract, re-exported from the engine so Institute
    /// validators declare against the Institute nest while conforming to
    /// the one shared protocol the harness and registries run.
    public typealias Validator = GitHub.ContinuousIntegration.Validation.Validator
    public typealias Rule = GitHub.ContinuousIntegration.Validation.Rule
    public typealias Finding = GitHub.ContinuousIntegration.Validation.Finding
    public typealias Subject = GitHub.ContinuousIntegration.Validation.Subject
    public typealias EnvironmentDefect = GitHub.ContinuousIntegration.Validation.EnvironmentDefect
    public typealias Retired = GitHub.ContinuousIntegration.Validation.Retired
}
