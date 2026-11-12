import Command
import File_System
import Institute_Model
import Testing

import struct Swift.String

@testable import Institute_Command

@Test
func `lint takes no argument, and --fix and --report when given`() throws {
    let plain = try Command.parse(Institute.Application.Lint.self, from: [], initial: .init())
    #expect(!plain.fix)
    #expect(plain.report.isEmpty)

    let fixing = try Command.parse(
        Institute.Application.Lint.self,
        from: ["--fix", "--report", "/tmp/report.json"],
        initial: .init()
    )
    #expect(fixing.fix)
    #expect(fixing.report == "/tmp/report.json")

    #expect(throws: Command.Error.self) {
        _ = try Command.parse(
            Institute.Application.Lint.self,
            from: ["--repository", "swift-atoms/swift-geometry"],
            initial: .init()
        )
    }
}

@Test
func `institute lint is a verb of the institute command`() throws {
    let command = try Command.parse(
        Institute.Application.CLI.self,
        from: ["lint", "--fix"],
        initial: .install(.init())
    )
    guard case .lint(let lint) = command else {
        Issue.record("institute lint parsed as another verb")
        return
    }
    #expect(lint.fix)
}
