public import Institute_Model

// Nest.Name namespace shell. `Institute.Repository.Policy.Ruleset` owns the
// Institute protected-main ruleset contracts — the payload classes the
// `rulesets` convergence job applies and reads back. The domain declares
// the namespace and its pure convergence semantics
// (`Ruleset.Convergence`); the application owns the payload readers that
// touch a checkout's `Policy/` files.
extension Institute.Repository.Policy {
    public enum Ruleset {}
}
