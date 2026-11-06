import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Idiom

extension `Lint.Rule Tests` {
    @Suite struct `task sleep Tests` {
        static func findings(_ source: Swift.String, file: Swift.String = "Sources/Poller/Poll.swift") -> Int {
            Lint.Rule.`task sleep`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings.count
        }

        @Test func `Task.sleep and Thread.sleep in sources are findings`() {
            #expect(Self.findings("func f() async throws { try await Task.sleep(for: .seconds(1)) }") == 1)
            #expect(Self.findings("func f() async throws { try await Task.sleep(nanoseconds: 1) }") == 1)
            #expect(Self.findings("func f() { Thread.sleep(forTimeInterval: 1) }") == 1)
        }

        @Test func `a clock passed in, a test, and an unrelated sleep are not`() {
            #expect(Self.findings("func f<C: Clock<Duration>>(clock: C) async throws { try await clock.sleep(for: .seconds(1)) }") == 0)
            #expect(Self.findings("func f() async throws { try await Task.sleep(for: .seconds(1)) }", file: "Tests/Poller Tests/Poll.swift") == 0)
            #expect(Self.findings("func f() async throws { try await other.Task.sleep(for: .seconds(1)) }") == 0)
        }

        @Test func `the rule's controls hold`() {
            for outcome in Lint.Rule.`task sleep`.outcomes() { #expect(outcome.holds, "\(outcome)") }
        }
    }
}
