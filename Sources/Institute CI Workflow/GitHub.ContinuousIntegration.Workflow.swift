import Institute_CI_GitHub
import GitHub_Standard

// Nest.Name namespace shell. `GitHub.ContinuousIntegration.Workflow` owns the *document* half of
// the validator contract: reading a GitHub Actions workflow file into a
// typed value. Rule predicates over that value belong to `GitHub.ContinuousIntegration.Validation`;
// subject/event/plan/aggregate semantics stay with the generic contract
// (swift-foundations/swift-continuous-integration, `ContinuousIntegration`).
extension GitHub.ContinuousIntegration {
    public enum Workflow {}
}
