import Command
import Institute_Model
import JSON
import Testing

@testable import Institute_Command
@testable import Institute_Version

/// Parses one argv through the typed router, exactly as `main.swift` does.
private func parse(
    _ argv: [Swift.String]
) throws -> Institute.Application.CLI {
    try Command.parse(Institute.Application.CLI.self, from: argv, initial: .install(.init()))
}

extension Institute.Version.Command {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Institute.Version.Command.Test.Unit {
    @Test
    func `version organizations selects the roster verb`() throws {
        guard case .version(.organizations) = try parse(["version", "organizations"]) else {
            Issue.record("expected version organizations")
            return
        }
    }

    @Test
    func `the workflow matrix is Institute.Organization, every case in order`() throws {
        let json = try JSON.parse([Byte](utf8: Institute.Version.Command.Organizations.matrix))
        let names = try #require(json.array).compactMap { Swift.String($0 as JSON?) }
        #expect(names == Institute.Organization.allCases.map(\.rawValue))
        #expect(names.count == 19)
        #expect(names.contains("swift-bipm"))
    }

    @Test
    func `version tag parses backfill and dry run`() throws {
        guard case .version(.tag(let tag)) = try parse(["version", "tag", "--backfill", "--dry-run"]) else {
            Issue.record("expected version tag")
            return
        }
        #expect(tag.backfill)
        #expect(tag.dryRun)
    }
}
