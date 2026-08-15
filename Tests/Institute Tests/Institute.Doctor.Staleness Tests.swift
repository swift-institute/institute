import Foundation
import Testing

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

extension Institute.Doctor.Fixture {
    /// Creates an empty directory relative to the sibling hierarchy —
    /// `write(_:to:)` never creates its parent directories, so a fixture
    /// that nests a file (e.g. under `.swiftlint/RemoteConfigCache/v1/`)
    /// makes room for it first.
    func makeDirectory(_ relative: Swift.String) throws {
        try FileManager.default.createDirectory(
            at: base.appending(path: relative),
            withIntermediateDirectories: true
        )
    }
}

// MARK: - Resolution-currency sub-check (Institute#87)

extension Institute.Doctor.Test.Unit {
    @Test
    func `a stale resolution names the commit distance and the pinned commit's date`() {
        let outcome = Institute.Doctor.resolutionCurrency.run(
            population: [
                .init(
                    package: "swift-example",
                    dependency: "swift-json",
                    branch: "main",
                    pinned: "0000000000000000000000000000000000000000",
                    tip: "1111111111111111111111111111111111111111",
                    behind: 7,
                    pinnedAt: "2026-07-01T00:00:00Z"
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .warning, population: 1))
        let message = outcome.findings.first?.message ?? ""
        #expect(message.contains("swift-json"))
        #expect(message.contains("7 commits behind"))
        #expect(message.contains("2026-07-01T00:00:00Z"))
        #expect(message.contains("000000000000"))
        #expect(message.contains("111111111111"))
        #expect(outcome.findings.allSatisfy { $0.severity == .warning })
    }

    @Test
    func `a pin at its tip is not a resolution-currency finding`() {
        let outcome = Institute.Doctor.resolutionCurrency.run(
            population: [
                .init(
                    package: "swift-example",
                    dependency: "swift-json",
                    branch: "main",
                    pinned: "0000000000000000000000000000000000000000",
                    tip: "0000000000000000000000000000000000000000",
                    behind: 0,
                    pinnedAt: ""
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .ok(population: 1))
    }
}

extension Institute.Doctor.Test.Integration {
    private static let repository = Institute.Repository(
        name: "swift-example",
        url: "https://github.com/swift-foundations/swift-example.git",
        organization: "swift-foundations",
        layer: .foundations
    )

    private static let noDiscovery:
        @Sendable () async throws(Institute.Error) ->
            Institute.Inventory.Discovery = {
                .init(repositories: [], exclusions: [])
            }

    @Test
    func
        `a stale resolution is measured through the checkout, naming the compare's distance and date`()
        async throws
    {
        let fixture = try Institute.Doctor.Fixture(repositories: [Self.repository])
        defer { fixture.remove() }
        try fixture.materialize("swift-example")
        try fixture.write(
            Institute.Doctor.Test.Unit.resolved,
            to: "swift-foundations/swift-example/Package.resolved"
        )

        let report = await fixture.doctor(tool: {
            executable,
            arguments throws(Institute.Error) -> Swift.String in
            if executable == "git", arguments.first == "ls-remote" {
                return "1111111111111111111111111111111111111111\trefs/heads/main\n"
            }
            if executable == "gh", arguments.first == "api",
                arguments.last?.contains("/compare/") == true
            {
                return #"""
                    {"ahead_by": 4, "base_commit": {"commit": {"committer": {"date": "2026-07-20T09:00:00Z"}}}}
                    """#
            }
            return Institute.Doctor.Fixture.interrogation(executable, arguments)
        }).run(access: .institute(inventory: Self.noDiscovery))

        let staleness = report.outcomes.first { $0.check == "resolution-currency" }
        #expect(staleness?.result == .finding(severity: .warning, population: 1))
        #expect(
            staleness?.findings.contains {
                $0.message.contains("swift-json") && $0.message.contains("4 commits behind")
                    && $0.message.contains("2026-07-20T09:00:00Z")
            } == true
        )
    }

    @Test
    func `resolution-currency is unmeasured, never fresh, when the compare cannot be read`()
        async throws
    {
        let fixture = try Institute.Doctor.Fixture(repositories: [Self.repository])
        defer { fixture.remove() }
        try fixture.materialize("swift-example")
        try fixture.write(
            Institute.Doctor.Test.Unit.resolved,
            to: "swift-foundations/swift-example/Package.resolved"
        )

        let report = await fixture.doctor(tool: {
            executable,
            arguments throws(Institute.Error) -> Swift.String in
            if executable == "git", arguments.first == "ls-remote" {
                return "1111111111111111111111111111111111111111\trefs/heads/main\n"
            }
            if executable == "gh", arguments.first == "api",
                arguments.last?.contains("/compare/") == true
            {
                throw .process("could not resolve host")
            }
            return Institute.Doctor.Fixture.interrogation(executable, arguments)
        }).run(access: .institute(inventory: Self.noDiscovery))

        let staleness = report.outcomes.first { $0.check == "resolution-currency" }
        guard case .unmeasured(let reason) = staleness?.result else {
            Issue.record("expected unmeasured, got \(String(describing: staleness?.result))")
            return
        }
        #expect(reason.contains("never fresh"))
    }

    @Test
    func `resolution-currency reports contributor runs as not applicable`() async throws {
        let fixture = try Institute.Doctor.Fixture(repositories: [])
        defer { fixture.remove() }
        try Institute.Xcode.write([], at: fixture.directory)

        let report = await fixture.doctor().run(access: .contributor)

        let staleness = report.outcomes.first { $0.check == "resolution-currency" }
        #expect(staleness?.result == .notApplicable(scope: .instituteInternal))
    }
}

// MARK: - Lint-config-currency sub-check (Institute#87)

extension Institute.Doctor.Test.Unit {
    @Test
    func `a lagging cached lint config warns naming its source`() {
        let outcome = Institute.Doctor.lintConfigCurrency.run(
            population: [
                .init(
                    root: "swift-example",
                    source:
                        "https://raw.githubusercontent.com/swift-institute/.github/main/.swiftlint.yml",
                    current: false
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .warning, population: 1))
        let message = outcome.findings.first?.message ?? ""
        #expect(message.contains("swift-example"))
        #expect(message.contains(".swiftlint.yml"))
        #expect(message.contains("lags"))
    }

    @Test
    func `a current cached lint config is not a finding`() {
        let outcome = Institute.Doctor.lintConfigCurrency.run(
            population: [
                .init(
                    root: "swift-example",
                    source:
                        "https://raw.githubusercontent.com/swift-institute/.github/main/.swiftlint.yml",
                    current: true
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .ok(population: 1))
    }
}

extension Institute.Doctor.Test.Integration {
    private static let cacheHeader = """
        #
        # Automatically downloaded from https://raw.githubusercontent.com/swift-institute/.github/main/.swiftlint.yml by SwiftLint on 30/07/2026 at 18:24:43.
        #

        """

    @Test
    func `no cached lint config anywhere is a proven zero, not a failure`() async throws {
        let repository = Institute.Repository(
            name: "swift-example",
            url: "https://github.com/swift-foundations/swift-example.git",
            organization: "swift-foundations",
            layer: .foundations
        )
        let fixture = try Institute.Doctor.Fixture(repositories: [repository])
        defer { fixture.remove() }
        try fixture.materialize("swift-example")

        let report = await fixture.doctor().run(access: .institute(inventory: Self.noDiscovery))

        let cache = report.outcomes.first { $0.check == "lint-config-currency" }
        #expect(cache?.result == .ok(population: 0))
    }

    @Test
    func `a stale cached lint config is measured against a live fetch and warns`() async throws {
        let repository = Institute.Repository(
            name: "swift-example",
            url: "https://github.com/swift-foundations/swift-example.git",
            organization: "swift-foundations",
            layer: .foundations
        )
        let fixture = try Institute.Doctor.Fixture(repositories: [repository])
        defer { fixture.remove() }
        try fixture.materialize("swift-example")
        try fixture.makeDirectory("swift-foundations/swift-example/.swiftlint/RemoteConfigCache/v1")
        try fixture.write(
            Self.cacheHeader + "rule_one: true\n",
            to: "swift-foundations/swift-example/.swiftlint/RemoteConfigCache/v1/cached.yml"
        )

        let report = await fixture.doctor(tool: {
            executable,
            arguments throws(Institute.Error) -> Swift.String in
            if executable == "gh", arguments.first == "api", arguments.contains("-H") {
                return "rule_one: true\nrule_two: true\n"
            }
            return Institute.Doctor.Fixture.interrogation(executable, arguments)
        }).run(access: .institute(inventory: Self.noDiscovery))

        let cache = report.outcomes.first { $0.check == "lint-config-currency" }
        #expect(cache?.result == .finding(severity: .warning, population: 1))
        #expect(
            cache?.findings.contains {
                $0.message.contains("swift-example") && $0.message.contains(".swiftlint.yml")
            } == true
        )
    }

    @Test
    func `a current cached lint config measures ok against a matching live fetch`() async throws {
        let repository = Institute.Repository(
            name: "swift-example",
            url: "https://github.com/swift-foundations/swift-example.git",
            organization: "swift-foundations",
            layer: .foundations
        )
        let fixture = try Institute.Doctor.Fixture(repositories: [repository])
        defer { fixture.remove() }
        try fixture.materialize("swift-example")
        try fixture.makeDirectory("swift-foundations/swift-example/.swiftlint/RemoteConfigCache/v1")
        try fixture.write(
            Self.cacheHeader + "rule_one: true\n",
            to: "swift-foundations/swift-example/.swiftlint/RemoteConfigCache/v1/cached.yml"
        )

        let report = await fixture.doctor(tool: {
            executable,
            arguments throws(Institute.Error) -> Swift.String in
            if executable == "gh", arguments.first == "api", arguments.contains("-H") {
                return "rule_one: true\n"
            }
            return Institute.Doctor.Fixture.interrogation(executable, arguments)
        }).run(access: .institute(inventory: Self.noDiscovery))

        let cache = report.outcomes.first { $0.check == "lint-config-currency" }
        #expect(cache?.result == .ok(population: 1))
    }

    @Test
    func `lint-config-currency reports contributor runs as not applicable`() async throws {
        let fixture = try Institute.Doctor.Fixture(repositories: [])
        defer { fixture.remove() }
        try Institute.Xcode.write([], at: fixture.directory)

        let report = await fixture.doctor().run(access: .contributor)

        let cache = report.outcomes.first { $0.check == "lint-config-currency" }
        #expect(cache?.result == .notApplicable(scope: .instituteInternal))
    }
}
