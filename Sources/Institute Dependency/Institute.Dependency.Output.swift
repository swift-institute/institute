public import Institute_Model
internal import Institute_Inventory

public import Command

extension Institute.Dependency {
    /// Rendering selected for the dependency audit.
    public enum Output: Sendable, Equatable, Argument.Codable {
        case human
        case json

        public init?(argument: Swift.String) {
            switch argument {
            case "human": self = .human
            case "json": self = .json
            default: return nil
            }
        }

        public var argumentDescription: Swift.String {
            switch self {
            case .human: "human"
            case .json: "json"
            }
        }
    }
}
