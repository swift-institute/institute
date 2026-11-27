internal import Institute_Model

extension Institute.Inventory.Walker.Scope {
    /// What opened a scope.
    enum Kind { case type, `extension`, generics }
}
