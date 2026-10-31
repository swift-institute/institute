#if LinterRuleBuildErrors
    public import Lint
    import Institute_Linter_Rule_SQL

    extension Lint.Rule.Bundle {

        /// The rules whose findings fail a build, each pinned to `error`.
        ///
        /// `swift-linter-build-errors` and its build-tool plugin run exactly this bundle, and a `Lint.swift` that lists
        /// only this bundle runs the same rules through `swift-linter`. A rule joins it when a finding is a hang or a
        /// defect that must stop the build, never when it is a matter of style.
        public static let buildErrors: [Lint.Rule.Configuration] = [
            .enable(.`database closure type`, severity: .error)
        ]
    }
#endif
