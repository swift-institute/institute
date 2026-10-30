public import Institute_Model
public import Institute_Repository_Policy

extension Institute.Repository.Policy.Command {
    /// Every way one repository subcommand refuses, preserving the
    /// refusing domain's own typed error. `execute` renders whichever
    /// domain refused and exits non-zero.
    public enum Error: Swift.Error, CustomStringConvertible {
        case configuration(String)
        case census(Institute.Repository.Policy.Census.Generator.Error)
        case metadata(Institute.Repository.Policy.Metadata.Error)
        case io(String)

        public var description: String {
            switch self {
            case .configuration(let message): return message
            case .census(let error): return "\(error)"
            case .metadata(let error): return "\(error)"
            case .io(let message): return message
            }
        }
    }
}
