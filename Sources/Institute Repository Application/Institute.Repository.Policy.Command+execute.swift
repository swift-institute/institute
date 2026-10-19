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

            case "caller-wave":
                try await callerWave(rest)

            case "uniformity-wave":
                try await uniformityWave(rest)

            default:
                throw Error.configuration(
                    "institute repository requires census, capability-records, "
                        + "render-caller, draft-metadata, ruleset, "
                        + "ruleset-convergence, caller-wave, or uniformity-wave"
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

    /// The value of a key ``require(_:keys:operation:)`` already
    /// established, or a configuration error naming it.
    static func value(
        _ key: Swift.String,
        in values: [Swift.String: Swift.String]
    ) throws(Error) -> Swift.String {
        guard let value = values[key] else { throw configuration("\(key) is required") }
        return value
    }

    static func require(
        _ values: [Swift.String: Swift.String],
        keys: [Swift.String],
        operation: Swift.String
    ) throws(Error) {
        guard values.count == keys.count, keys.allSatisfy({ values[$0] != nil }) else {
            throw configuration(
                "\(operation) requires \(keys.joined(separator: ", "))"
            )
        }
    }

    static func values(_ arguments: [Swift.String]) throws(Error) -> [Swift.String: Swift.String] {
        guard arguments.count.isMultiple(of: 2) else {
            throw configuration("arguments require values")
        }
        var values: [Swift.String: Swift.String] = [:]
        var iterator = arguments.makeIterator()
        while let key = iterator.next(), let value = iterator.next() {
            guard key.hasPrefix("--"), values.updateValue(value, forKey: key) == nil else {
                throw configuration("argument is invalid or repeated: \(key)")
            }
        }
        return values
    }
}
