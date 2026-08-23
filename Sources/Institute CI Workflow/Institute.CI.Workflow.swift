public import Institute_CI_Model
public import Institute_Model

// Nest.Name namespace shell. `Institute.CI.Workflow` owns the *document* half of
// the validator contract: reading a GitHub Actions workflow file into a
// typed value. Rule predicates over that value belong to
// `Institute.CI.Validation`; subject/event/plan/aggregate semantics stay
// with `Institute.CI` itself.
extension Institute.CI {
    public enum Workflow {}
}
