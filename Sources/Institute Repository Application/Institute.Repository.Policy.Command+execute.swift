import Console
public import Institute_Model
public import Institute_Repository_Policy
import Process

import struct Swift.String

extension Institute.Repository.Policy.Command {
    public static func execute(_ arguments: [Swift.String]) async {
        do {
            let operation = arguments.first
            let rest = Array(arguments.dropFirst())
            switch operation {
            case "census":
                try census(rest)

            case "capability-records":
                try capabilityRecords(rest)

            case "render-caller":
                try renderCaller(rest)

            case "draft-metadata":
                try draftMetadata(rest)

            case "ruleset":
                try ruleset(RulesetArguments(rest))

            case "ruleset-convergence":
                try rulesetConvergence(RulesetConvergenceArguments(rest))

            default:
                throw Error.configuration(
                    "institute repository requires census, capability-records, "
                        + "render-caller, draft-metadata, ruleset, "
                        + "or ruleset-convergence"
                )
            }
        } catch {
            Console.Output.error("institute repository: \(error)")
            Process.Exit.normal(1)
        }
    }

    static func configuration(_ message: Swift.String) -> Error {
        .configuration(message)
    }
}
