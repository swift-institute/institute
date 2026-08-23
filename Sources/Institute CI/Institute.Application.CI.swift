// Licensed under the Apache License, Version 2.0.

import Foundation
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import Institute_CI_Validation
import Process

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

extension Institute.Application {
    enum CI {}
}

extension Institute.Application.CI {
    static func execute(_ arguments: [Swift.String]) {
        do throws(Error) {
            try run(arguments)
        } catch {
            FileHandle.standardError.write(
                Data("institute ci: \(error.message)\n".utf8)
            )
            terminate(2)
        }
    }

    private static func run(_ arguments: [Swift.String]) throws(Error) {
        // The workflow verbs dispatch first and exit on their own verdict;
        // everything else is the gitignore command's argument grammar.
        if let first = arguments.first, let verb = Verb(rawValue: first) {
            run(verb, Array(arguments.dropFirst()))
            return
        }
        let action: ContinuousIntegration.Command.Gitignore.Action
        do throws(ContinuousIntegration.Command.Gitignore.Error) {
            action = try ContinuousIntegration.Command.Gitignore.parse(
                arguments
            )
        } catch {
            throw .command(error)
        }
        switch action {
        case .render(let canon, let target):
            guard let canon = read(canon) else { throw .unreadable(canon) }
            let existing = target.flatMap(read)
            let rendered: String
            do throws(ContinuousIntegration.Command.Gitignore.Error) {
                rendered = try ContinuousIntegration.Command.Gitignore.render(
                    canon: canon,
                    target: existing
                )
            } catch {
                throw .command(error)
            }
            print(rendered, terminator: "")

        case .validate(let repository, let root, let canon):
            let findings: [ContinuousIntegration.Validation.Finding]
            do throws(ContinuousIntegration.Validation.EnvironmentDefect) {
                findings = try ContinuousIntegration.Command.Gitignore.findings(
                    repository: repository,
                    root: root,
                    canon: canon
                )
            } catch {
                throw .environment(error)
            }
            print(
                ContinuousIntegration.Command.Gitignore.encoded(findings: findings),
                terminator: ""
            )

        case .fixtures(let corpus):
            let report: GitHub.ContinuousIntegration.Validation.Harness.Report
            do throws(ContinuousIntegration.Validation.EnvironmentDefect) {
                report = try ContinuousIntegration.Command.Gitignore.fixtures(
                    corpus: corpus
                )
            } catch {
                throw .environment(error)
            }
            for outcome in report.outcomes { print(outcome.summary) }
            guard report.unownedRuleDirectories.isEmpty else {
                throw .unowned(report.unownedRuleDirectories)
            }
            guard report.isSatisfied else { terminate(1) }
        }
    }

    static func terminate(_ status: Swift.Int32) -> Never {
        Process.Exit.normal(status)
    }

    private static func read(_ path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
