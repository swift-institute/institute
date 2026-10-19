internal import Institute_Development
internal import Institute_Inventory
public import Institute_Model
internal import Institute_Pages

extension Institute.Doctor.Manifest {
    public enum Identity: Equatable, Sendable {
        case evaluated(Swift.String)
        case unevaluable(Swift.String)
    }
}
