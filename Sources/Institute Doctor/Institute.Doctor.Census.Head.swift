internal import Institute_Development
internal import Institute_Inventory
internal import Institute_Lint
public import Institute_Model
internal import Institute_Pages

extension Institute.Doctor.Census {
    /// Where a repository's HEAD is: on a named branch, or detached.
    public enum Head: Equatable, Sendable {
        case branch(Swift.String)
        case detached
    }
}
