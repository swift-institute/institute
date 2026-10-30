import Byte
import Console
import File_System
public import Institute_CI_Model
import Institute_CI_Validation
public import Institute_Model
import JSON
import Process

import struct Swift.String

extension Institute.CI.Command {
    public static func execute(_ arguments: [Swift.String]) async {
        do throws(Error) {
            try await run(arguments)
        } catch {
            Console.Output.error("institute ci: \(error.message)")
            terminate(2)
        }
    }

    private static func run(_ arguments: [Swift.String]) async throws(Error) {
        // The workflow verbs dispatch first and exit on their own verdict;
        // everything else is the gitignore command's argument grammar.
        if let first = arguments.first, let verb = Verb(rawValue: first) {
            await run(verb, Array(arguments.dropFirst()))
            return
        }
        let action: Gitignore.Action
        do throws(Gitignore.Error) {
            action = try Gitignore.parse(arguments)
        } catch {
            throw .command(error)
        }
        switch action {
        case .render(let canon, let target):
            guard let canon = text(atPath: canon) else { throw .unreadable(canon) }
            let existing = target.flatMap(text(atPath:))
            let rendered: Swift.String
            do throws(Gitignore.Error) {
                rendered = try Gitignore.render(canon: canon, target: existing)
            } catch {
                throw .command(error)
            }
            print(rendered, terminator: "")

        case .validate(let repository, let root, let canon):
            let findings: [Institute.CI.Validation.Finding]
            do throws(Institute.CI.Validation.EnvironmentDefect) {
                findings = try Gitignore.findings(
                    repository: repository,
                    root: root,
                    canon: canon
                )
            } catch {
                throw .environment(error)
            }
            print(Gitignore.encoded(findings: findings), terminator: "")

        case .fixtures(let corpus):
            let report: Institute.CI.Validation.Harness.Report
            do throws(Institute.CI.Validation.EnvironmentDefect) {
                report = try Gitignore.fixtures(corpus: corpus)
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

    public static func terminate(_ status: Swift.Int32) -> Never {
        Process.Exit.normal(status)
    }

    static func value(_ flag: Swift.String, in arguments: [Swift.String]) -> Swift.String {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count
        else { return "" }
        return arguments[index + 1]
    }

    static func refuse(_ message: Swift.String) -> Never {
        Console.Output.error("institute ci: \(message)")
        terminate(1)
    }

    /// Prints one JSON object with deterministically sorted keys — the
    /// wire format every workflow step consuming these verbs parses.
    static func emit(_ payload: [Swift.String: JSON]) {
        print(JSON.object(payload.map { ($0.key, $0.value) }).serialize(sortKeys: true))
    }

    /// The decoded root object of a JSON document, or a refusal naming
    /// what could not be read. One reader for both callers below, so a
    /// malformed document reports the same way wherever it arrives.
    static func decoded(_ text: Swift.String, _ subject: Swift.String) -> [Swift.String: JSON] {
        let value: JSON
        do throws(JSON.Error) {
            value = try JSON.parse(text)
        } catch {
            refuse("\(subject): malformed JSON: \(error)")
        }
        guard let root = value.dictionary else {
            refuse("\(subject): expected a JSON object at the root")
        }
        return root
    }

    static func run(_ verb: Verb, _ rest: [Swift.String]) async {
        switch verb {
        case .packageCommand: package(rest)
        case .control: control(rest)
        case .source: await source(rest)

        case .bootstrapIdentity, .bootstrapManifest, .bootstrapVerify:
            bootstrap(verb, rest)
        }
    }

    /// The verbs the universal reusable workflow invokes. Each maps
    /// arguments onto an owner and prints its result; the decisions are
    /// the owners', and the exit status is the verdict.
    enum Verb: Swift.String {
        case packageCommand = "package"
        case control
        case source
        case bootstrapManifest = "bootstrap-manifest"
        case bootstrapVerify = "bootstrap-verify"
        case bootstrapIdentity = "bootstrap-identity"
    }

    /// The bytes of the file at `path`, or `nil` when the path is
    /// invalid, missing, or unreadable.
    static func contents(atPath path: Swift.String) -> [Byte]? {
        guard let filePath = try? File.Path(path) else { return nil }
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try File(filePath).read.full { view in
                var storage = [Byte]()
                storage.reserveCapacity(view.count)
                for index in view.indices {
                    storage.append(view[index])
                }
                return storage
            }
        } catch {
            return nil
        }
    }

    /// The UTF-8 text of the file at `path`, or `nil` when unreadable.
    static func text(atPath path: Swift.String) -> Swift.String? {
        contents(atPath: path).map { Swift.String(decoding: $0, as: Swift.UTF8.self) }
    }
}
