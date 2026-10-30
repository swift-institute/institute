import Lint
import Testing

@testable import Linter_Primitives_Rules

@Suite
struct `Lint Rule Bundle primitives Tests` {
    static func effectiveSeverity(of id: Swift::String) -> Diagnostic.Severity? {
        Lint.Rule.Bundle.primitives
            .first { $0.rule.id.underlying == id }
            .map { $0.severity ?? $0.rule.severity.default }
    }

    @Test(arguments: ["carrier column bound", "clone-less box"])
    func `rules graduated after two clean fleet measurements are errors`(id: Swift::String) {
        #expect(Self.effectiveSeverity(of: id) == .error)
    }
}
