public import Institute_Model
internal import Institute_Inventory
internal import Institute_Development
internal import Institute_Doctor
internal import Institute_Lint

extension Institute.Verification {
    /// What a verification run records about the effective inventory it was
    /// measured against.
    ///
    /// Distinct from ``Institute/Inventory``, which *produces* the
    /// inventory: this namespace holds only what a receipt carries about
    /// one.
    public enum Inventory {}
}
