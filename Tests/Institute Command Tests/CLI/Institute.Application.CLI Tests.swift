import Command
import Institute_Model
import Testing

@testable import Institute_Command

/// Parses one argv through the typed router, exactly as `main.swift` does.
private func parse(
    _ argv: [Swift.String]
) throws -> Institute.Application.CLI {
    try Command.parse(Institute.Application.CLI.self, from: argv, initial: .install(.init()))
}

extension Institute.Application.CLI {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Application.CLI.Test.Unit {
    @Test
    func `install selects the command bootstrap`() throws {
        let command = try parse(["install"])

        guard case .install = command else {
            Issue.record("expected install, got \(command)")
            return
        }
    }
}

extension Institute.Application.CLI.Test.`Edge Case` {
    @Test
    func `install takes no mode`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["install", "check"])
        }
    }

    @Test
    func `install rejects package arguments`() {
        #expect(throws: Command.Error.self) {
            _ = try parse(["install", "--package-path", "Application"])
        }
    }

    @Test
    func `a bare invocation names a subcommand instead of running one`() {
        #expect(throws: Command.Error.self) {
            _ = try parse([])
        }
    }

    @Test(arguments: [
        ["sync"],
        ["workspace", "materialize"],
        ["build"],
        ["doctor"],
        ["inventory"],
        ["dependencies"],
        ["compose", "--consumer", "a", "--dependency", "b"],
        ["restore", "--consumer", "a", "--dependency", "b"],
        ["verify", "--consumer", "a", "--dependency", "b"],
        ["context", "install"],
        ["package", "build"],
        ["coherence"],
        ["conversion", "seal"],
        ["verification", "seal"],
        ["certification", "snapshot"],
        ["architecture", "validate"],
        ["source", "measure"],
        ["lint"],
    ])
    func `retired command surfaces are rejected`(arguments: [Swift.String]) {
        #expect(throws: Command.Error.self) {
            _ = try parse(arguments)
        }
    }
}
