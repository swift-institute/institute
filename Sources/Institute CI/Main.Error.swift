// Licensed under the Apache License, Version 2.0.

import Institute_CI_Validation

extension Institute.Application.CI {
    enum Error: Swift.Error {
        case command(ContinuousIntegration.Command.Gitignore.Error)
        case unreadable(String)
        case environment(ContinuousIntegration.Validation.EnvironmentDefect)
        case unowned([String])
    }
}

extension Institute.Application.CI.Error {
    var message: String {
        switch self {
        case .command(let error): error.message

        case .unreadable(let path): "could not read `\(path)`"

        case .environment(let error): error.message

        case .unowned(let directories):
            "unowned Gitignore fixture directories: \(directories.joined(separator: ", "))"
        }
    }
}
