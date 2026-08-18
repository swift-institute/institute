internal import Institute_Inventory
public import Institute_Model

extension Institute.Dependency.Exclusion {
    public enum Kind: Swift.String, Equatable, Sendable {
        case path
        case registry
        case malformed
    }
}
