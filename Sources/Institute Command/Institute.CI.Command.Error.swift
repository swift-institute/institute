public import Institute_CI_Model
public import Institute_CI_Validation
public import Institute_Model

extension Institute.CI.Command {
    /// Every way the CI command family refuses, preserving the refusing
    /// domain's own typed error.
    public enum Error: Swift.Error {
        case command(Institute.CI.Command.Gitignore.Error)
        case unreadable(String)
        case environment(Institute.CI.Validation.EnvironmentDefect)
        case unowned([String])
    }
}

extension Institute.CI.Command.Error {
    public var message: String {
        switch self {
        case .command(let error): error.message

        case .unreadable(let path): "could not read `\(path)`"

        case .environment(let error): error.message

        case .unowned(let directories):
            "unowned Gitignore fixture directories: \(directories.joined(separator: ", "))"
        }
    }
}
