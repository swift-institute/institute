public import Institute_Model

extension Institute.Architecture.Exemption {
    /// Why an exemption could not be constructed.
    public enum Error: Swift.Error, Sendable, Equatable {
        case emptyReason(owner: Institute.Architecture.Owner)
        case malformedExpiry(Swift.String)
    }
}
