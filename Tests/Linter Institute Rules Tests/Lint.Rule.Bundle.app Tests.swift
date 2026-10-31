import Lint
import Testing

@testable import Linter_Institute_Rules

@Suite
struct `Lint Rule Bundle app Tests` {
    @Suite struct Unit {}
}

extension `Lint Rule Bundle app Tests`.Unit {
    static var ids: [Swift::String] { Lint.Rule.Bundle.app.map(\.rule.id.underlying) }

    @Test
    func `the app bundle holds every institute rule`() {
        let missing = Swift::Set(Lint.Rule.Bundle.institute.map(\.rule.id.underlying)).subtracting(Self.ids)
        #expect(missing.isEmpty, "\(missing.sorted())")
    }

    @Test(arguments: ["framework import", "owned api", "view state", "view logic", "with animation", "feature user defaults"])
    func `the app bundle holds the framework, view and feature rules`(id: Swift::String) {
        #expect(Self.ids.contains(id), "\(id)")
    }

    @Test(arguments: ["view state", "view logic"])
    func `a view that holds state or logic is an error`(id: Swift::String) {
        #expect(Lint.Rule.Bundle.app.first { $0.rule.id.underlying == id }?.severity == .error, "\(id)")
    }

    @Test
    func `app bundle rule ids are unique`() {
        let ids = Self.ids
        #expect(ids.count == Swift::Set(ids).count)
    }
}
