public import Institute_Model
internal import Institute_Inventory

extension Institute.Dependency.Exclusion {
    public enum Kind: Swift.String, Equatable, Sendable {
        case path
        case registry
        case malformed
    }
}
