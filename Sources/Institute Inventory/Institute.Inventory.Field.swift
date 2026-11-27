public import Institute_Model

extension Institute.Inventory {
    /// One value of a table row.
    public enum Field: Sendable, Hashable {
        case text(Swift.String)
        case number(Swift.Int)
        case flag(Swift.Bool)
    }
}
