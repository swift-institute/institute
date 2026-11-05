import Lint
import Testing

@testable import Institute_Linter_Rule_Architecture

@Suite struct `Concept rules` {
    @Test func `raw concept's controls hold`() {
        for outcome in Lint.Rule.`raw concept`.outcomes() { #expect(outcome.holds, "\(outcome)") }
    }

    @Test func `concept parallel's controls hold`() {
        for outcome in Lint.Rule.`concept parallel`.outcomes() { #expect(outcome.holds, "\(outcome)") }
    }
}
