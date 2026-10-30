public import Institute_Model

// Nest.Name namespace shell. `Institute.CI` owns the Institute's
// continuous-integration semantics: the vendor-neutral
// subject/event/plan/aggregate vocabulary reabsorbed from the retired
// swift-continuous-integration package, preserving the required check
// context `ci / matrix / ci-ok`.
extension Institute {
    public enum CI {}
}
