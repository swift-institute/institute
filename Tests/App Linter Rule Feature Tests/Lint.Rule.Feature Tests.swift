import Lint
import Linter_Rules_Test_Support
import Testing

@testable import App_Linter_Rule_Feature

@Suite
struct `Feature Tests` {
    @Suite struct `User Defaults` {}
    @Suite struct `With Animation` {}
    @Suite struct Path {}
    @Suite struct Integration {}
}

extension `Feature Tests` {
    static func findings(
        _ rule: Lint.Rule,
        _ source: Swift::String,
        file: Swift::String = "Sources/Laurie/Sweep.swift"
    ) -> [Diagnostic.Record] {
        rule.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
    }

    static let outside = """
        struct Helper {
          @AppStorage("k") var stored = 0
          func f() { withAnimation { }; _ = UserDefaults.standard }
        }
        """
}

extension `Feature Tests`.`User Defaults` {
    @Test
    func `user defaults forms fire inside a feature`() {
        let source = """
            @MainActor @Feature public struct Sweep {
              struct State { @AppStorage("k") var stored = 0 }
              func f(_ d: UserDefaults) { _ = UserDefaults.standard; @Shared(.appStorage("x")) var x = 0 }
            }
            """
        #expect(`Feature Tests`.findings(.`feature user defaults`, source).count == 4)
    }

    @Test
    func `outside a feature does not fire`() {
        #expect(`Feature Tests`.findings(.`feature user defaults`, `Feature Tests`.outside).isEmpty)
    }

    @Test
    func `extension of a feature in the same file fires`() {
        let source = """
            extension Laurie { @Feature struct Sweep {} }
            extension Laurie.Sweep { func f() { _ = UserDefaults.standard } }
            """
        #expect(`Feature Tests`.findings(.`feature user defaults`, source).count == 1)
    }

    @Test
    func `extension of a feature in another file fires`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Sources/Laurie/Sweep.swift": "extension Laurie { @Feature struct Sweep {} }",
            "Sources/Laurie/Sweep+Body.swift": "extension Laurie.Sweep { func f() { withAnimation { } } }",
        ])
        let findings = Lint.Rule.`feature with animation`.observe(
            fixture.parsed("Sources/Laurie/Sweep+Body.swift"),
            .warning
        ).findings
        #expect(findings.count == 1)
    }
}

extension `Feature Tests`.`With Animation` {
    @Test
    func `withAnimation fires inside a feature`() {
        let source = "@Feature struct Sweep { func f() { withAnimation(.default) { }; SwiftUI.withAnimation { } } }"
        #expect(`Feature Tests`.findings(.`feature with animation`, source).count == 2)
    }

    @Test
    func `Observing animation does not fire`() {
        let source = "@Feature struct Sweep { var rows = Observing(query).animation() }"
        #expect(`Feature Tests`.findings(.`feature with animation`, source).isEmpty)
    }

    @Test
    func `feature-named attribute lookalikes do not fire`() {
        let source = "@FeatureState struct Sweep { func f() { withAnimation { } } }"
        #expect(`Feature Tests`.findings(.`feature with animation`, source).isEmpty)
    }
}

extension `Feature Tests`.Path {
    @Test(arguments: [
        "Sources/Laurie Feature/Helper.swift",
        "Sources/Laurie Feature/Nested/Helper.swift",
        "Tests/Laurie Feature/Helper.swift",
    ])
    func `every file of a Feature target is in scope`(file: Swift::String) {
        let rule = Lint.Rule.`feature with animation`
        #expect(`Feature Tests`.findings(rule, `Feature Tests`.outside, file: file).count == 1)
        let defaults = Lint.Rule.`feature user defaults`
        #expect(`Feature Tests`.findings(defaults, `Feature Tests`.outside, file: file).count == 2)
    }

    @Test(arguments: [
        "Helper.swift",
        "Laurie Feature.swift",
        "Sources/Laurie Feature.swift",
        "Sources/Feature/Helper.swift",
        "Sources/LaurieFeature/Helper.swift",
        "Sources/Laurie Feature Tests/Helper.swift",
        "Sources/Laurie/Laurie Feature/Helper.swift",
        "Sources/ Feature/Helper.swift",
    ])
    func `near misses outside a Feature target do not fire`(file: Swift::String) {
        let rule = Lint.Rule.`feature with animation`
        #expect(`Feature Tests`.findings(rule, `Feature Tests`.outside, file: file).isEmpty)
    }

    @Test
    func `bare filename feature type still fires`() {
        let source = "@Feature struct Sweep { func f() { withAnimation { } } }"
        #expect(`Feature Tests`.findings(.`feature with animation`, source, file: "Sweep.swift").count == 1)
    }
}

extension `Feature Tests`.Integration {
    @Test
    func `controls hold for every rule`() {
        for rule in Lint.Rule.Bundle.feature.map(\.rule) {
            let outcomes = rule.outcomes()
            #expect(outcomes.contains { $0.expected > 0 }, "\(rule.id)")
            for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
        }
    }
}
