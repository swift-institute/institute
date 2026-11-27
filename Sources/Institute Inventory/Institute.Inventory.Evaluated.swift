internal import Institute_Model

extension Institute.Inventory {
    /// One package's evaluation, or why it has none.
    enum Evaluated: Sendable {
        case member(Member)
        case failure(Swift.String)
    }
}
