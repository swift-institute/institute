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
    func `organizations parses its layer`() throws {
        guard case .organizations(let command) = try parse(["organizations", "--layer", "standards"]) else {
            Issue.record("expected organizations")
            return
        }
        #expect(command.layer == "standards")
    }

    @Test
    func `the organizations matrix is Institute.Organization, every case in order`() throws {
        let names = try Self.names(Institute.Application.Organizations.matrix(layer: nil))
        #expect(names == Institute.Organization.allCases.map(\.rawValue))
        #expect(names.count == 19)
        #expect(names.contains("swift-bipm"))
    }

    @Test
    func `a layer narrows the matrix to that layer`() throws {
        #expect(try Self.names(Institute.Application.Organizations.matrix(layer: .atoms)) == ["swift-atoms"])
        let standards = try Self.names(Institute.Application.Organizations.matrix(layer: .standards))
        #expect(standards.count == 15)
        #expect(standards.contains("swift-standards"))
        #expect(standards.contains("swift-bipm"))
        #expect(!standards.contains("swift-compositions"))
    }

    @Test
    func `every layer has a name that reads back`() {
        for layer in Institute.Organization.Layer.allCases {
            let name = Institute.Application.Organizations.name(layer)
            #expect(Institute.Application.Organizations.layer(named: name) == layer)
        }
        #expect(Institute.Application.Organizations.layer(named: "primitives") == nil)
    }

    static func names(_ matrix: Swift.String) throws -> [Swift.String] {
        let json = try JSON.parse([Byte](utf8: matrix))
        return try #require(json.array).compactMap { Swift.String($0 as JSON?) }
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
