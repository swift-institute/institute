internal import Institute_Linter_Rule_Naming
internal import Institute_Linter_Rule_Structure
public import Lint
internal import Linter_Institute_Rules

extension Lint.Rule.Bundle {
    public static let standards: [Lint.Rule.Configuration] =
        Lint.Rule.Bundle.institute.excluding(rules: [
            Lint.Rule.`compound identifier`.id,
            Lint.Rule.`compound type name`.id,
            Lint.Rule.`file name nested path`.id,
            Lint.Rule.`extension file naming`.id,
        ])
}
