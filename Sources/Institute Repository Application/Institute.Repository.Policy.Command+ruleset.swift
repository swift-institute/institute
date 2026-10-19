import Byte
public import Institute_Model
public import Institute_Repository_Policy
import JSON

import struct Swift.String

extension Institute.Repository.Policy.Command {
    /// `institute repository ruleset --policy <json> [--class package|control-plane]
    /// [--visibility public|private]` — validates and prints the exact
    /// protected-main ruleset payload for the selected contract class.
    static func ruleset(_ arguments: RulesetArguments) throws(Error) {
        let policy = try bytes(at: arguments.policy, label: "protected-main ruleset policy")
        let payload: [Byte]
        do throws(Institute.Repository.Policy.Ruleset.Error) {
            switch (arguments.repositoryClass, arguments.visibility) {
            case (.package, .public):
                payload = try Institute.Repository.Policy.Ruleset.protectedMainPayload(from: policy)

            case (.package, .private):
                payload = try Institute.Repository.Policy.Ruleset.protectedMainPrivatePayload(from: policy)

            case (.controlPlane, _):
                payload = try Institute.Repository.Policy.Ruleset.protectedMainControlPayload(from: policy)
            }
        } catch {
            throw .ruleset(error)
        }
        print(Swift.String(payload))
    }

    /// The heal-existing-vs-skip-absent decision for one repository
    /// (swift-institute/.github#204). Pure and network-free: the caller
    /// resolves whether an Institute ruleset currently exists and passes
    /// that in, this only decides the mechanical action.
    static func rulesetConvergence(
        _ arguments: RulesetConvergenceArguments
    ) throws(Error) {
        let decision = Institute.Repository.Policy.Ruleset.decideConvergence(
            rulesetExists: arguments.rulesetExists,
            mode: arguments.mode
        )
        var bytes = [Byte](utf8: decision.jsonString(pretty: true, sortKeys: true))
        bytes.append(Byte(0x0A))
        print(Swift.String(bytes), terminator: "")
    }

    struct RulesetArguments {
        /// The two contract classes this verb renders. `tool` never has a
        /// payload; asking for one is a configuration refusal.
        enum Class {
            case package
            case controlPlane
        }

        /// Repository visibility, read live from GitHub
        /// (`GET /repos/{full_name}` → `.visibility`) by the caller — this
        /// type never has a default case and the CLI never infers it, so an
        /// unreadable visibility must fail closed one level up.
        enum Visibility: Swift.String {
            case `public`
            case `private`
        }

        let policy: Swift.String
        let repositoryClass: Class
        let visibility: Visibility

        init(_ arguments: [Swift.String]) throws(Error) {
            var values = [Swift.String: Swift.String]()
            var index = 0
            while index < arguments.count {
                let name = arguments[index]
                guard index + 1 < arguments.count else {
                    throw Institute.Repository.Policy.Command.configuration(
                        "missing value for \(name)"
                    )
                }
                guard name.hasPrefix("--") else {
                    throw Institute.Repository.Policy.Command.configuration(
                        "unknown argument \(name)"
                    )
                }
                values[name] = arguments[index + 1]
                index += 2
            }
            guard let policy = values.removeValue(forKey: "--policy") else {
                throw Institute.Repository.Policy.Command.configuration(
                    "ruleset requires --policy <path>"
                )
            }
            // Defaults to `package` so any caller predating the control-plane
            // variant (swift-institute/.github#200) keeps its prior behavior
            // unchanged.
            let classValue = values.removeValue(forKey: "--class") ?? "package"
            let repositoryClass: Class
            switch classValue {
            case "package": repositoryClass = .package
            case "control-plane": repositoryClass = .controlPlane

            default:
                throw Institute.Repository.Policy.Command.configuration(
                    "--class must be package or control-plane"
                )
            }
            // Defaults to `public` so every caller predating the visibility
            // dimension keeps its prior behavior unchanged. A control-plane
            // target ignores this value entirely — it selects no required
            // check context either way.
            let visibilityValue = values.removeValue(forKey: "--visibility") ?? "public"
            guard let visibility = Visibility(rawValue: visibilityValue) else {
                throw Institute.Repository.Policy.Command.configuration(
                    "--visibility must be public or private"
                )
            }
            guard values.isEmpty else {
                throw Institute.Repository.Policy.Command.configuration(
                    "unknown argument \(values.keys.sorted().joined(separator: ", "))"
                )
            }
            self.policy = policy
            self.repositoryClass = repositoryClass
            self.visibility = visibility
        }
    }

    struct RulesetConvergenceArguments {
        let mode: Institute.Repository.Policy.Ruleset.SweepMode
        let rulesetExists: Bool

        init(_ arguments: [Swift.String]) throws(Error) {
            var values = [Swift.String: Swift.String]()
            var index = 0
            while index < arguments.count {
                let name = arguments[index]
                guard index + 1 < arguments.count else {
                    throw Institute.Repository.Policy.Command.configuration(
                        "missing value for \(name)"
                    )
                }
                guard name.hasPrefix("--") else {
                    throw Institute.Repository.Policy.Command.configuration(
                        "unknown argument \(name)"
                    )
                }
                values[name] = arguments[index + 1]
                index += 2
            }
            guard
                let modeValue = values.removeValue(forKey: "--mode"),
                let mode = Institute.Repository.Policy.Ruleset.SweepMode(rawValue: modeValue)
            else {
                throw Institute.Repository.Policy.Command.configuration(
                    "ruleset-convergence requires --mode scheduled-heal or explicit-apply"
                )
            }
            guard
                let existingValue = values.removeValue(forKey: "--existing-ruleset"),
                let existing = Bool(existingValue)
            else {
                throw Institute.Repository.Policy.Command.configuration(
                    "ruleset-convergence requires --existing-ruleset true or false"
                )
            }
            guard values.isEmpty else {
                throw Institute.Repository.Policy.Command.configuration(
                    "unknown argument \(values.keys.sorted().joined(separator: ", "))"
                )
            }
            self.mode = mode
            self.rulesetExists = existing
        }
    }
}
