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

@Test
func `lint takes --rules, and --kind with it`() throws {
    let listing = try Command.parse(
        Institute.Application.Lint.self,
        from: ["--rules", "--kind", "test"],
        initial: .init()
    )
    #expect(listing.rules)
    #expect(listing.kind == "test")
    #expect(try Institute.Application.Lint.selection(rules: true, kind: "test", fix: false, report: "") == .test)
    #expect(try Institute.Application.Lint.selection(rules: true, kind: "", fix: false, report: "") == nil)
    #expect(try Institute.Application.Lint.selection(rules: false, kind: "", fix: true, report: "r.json") == nil)
}

@Test(arguments: [
    (true, "header", false, ""),
    (false, "test", false, ""),
    (true, "", true, ""),
    (true, "source", false, "report.json"),
])
func `lint refuses a kind that is none, --kind alone, and --rules with --fix or --report`(
    rules: Bool,
    kind: String,
    fix: Bool,
    report: String
) {
    #expect(throws: Institute.Error.self) {
        _ = try Institute.Application.Lint.selection(rules: rules, kind: kind, fix: fix, report: report)
    }
}
