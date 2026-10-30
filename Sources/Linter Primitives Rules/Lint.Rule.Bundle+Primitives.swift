public import Lint
internal import Linter_Institute_Rules
internal import Primitives_Linter_Rule_Tower

extension Lint.Rule.Bundle {

    public static let primitives: [Lint.Rule.Configuration] =
        Lint.Rule.Bundle.institute + [

            .enable(.`frozen tower type`),
            .enable(.`clone-less box`, severity: .error),

            .enable(.`carrier column bound`, severity: .error),
        ]
}
