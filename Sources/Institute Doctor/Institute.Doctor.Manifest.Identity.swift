public import Institute_Model
internal import Institute_Inventory
internal import Institute_Pages
internal import Institute_Development
internal import Institute_Lint

extension Institute.Doctor.Manifest {
    public enum Identity: Equatable, Sendable {
        case evaluated(Swift.String)
        case unevaluable(Swift.String)
    }
}
