public import Lint

extension Lint.Rule {

    public static let `feature user defaults` = Lint.Rule(
        id: "feature user defaults",
        default: .warning,
        controls: [
            .init(
                id: "feature user defaults in feature",
                source: """
                    @Feature struct Sweep {
                      func remembered() -> Bool { UserDefaults.standard.bool(forKey: "sweep") }
                    }
                    """,
                path: "Controls/FeatureUserDefaults.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "feature user defaults outside feature",
                source: """
                    struct Settings {
                      func remembered() -> Bool { UserDefaults.standard.bool(forKey: "sweep") }
                    }
                    """,
                path: "Controls/FeatureUserDefaultsOutside.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Feature.observe(
            .userDefaults,
            identifier: "feature user defaults",
            message: "This rule checks for `UserDefaults` references, `@AppStorage` and `.appStorage` "
                + "keys \(Lint.Feature.scope). Anything persisted lives in SQLite. Fix: store the value in "
                + "a table and read it through the screen's `Observing<…>.State` field."
        )
    )

    public static let `feature with animation` = Lint.Rule(
        id: "feature with animation",
        default: .warning,
        controls: [
            .init(
                id: "feature with animation in feature",
                source: """
                    @Feature struct Sweep {
                      func flag() { withAnimation { } }
                    }
                    """,
                path: "Controls/FeatureWithAnimation.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "feature with animation outside feature",
                source: """
                    struct Helper {
                      func flag() { withAnimation { } }
                    }
                    """,
                path: "Controls/FeatureWithAnimationOutside.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Feature.observe(
            .withAnimation,
            identifier: "feature with animation",
            message: "This rule checks for `withAnimation` calls \(Lint.Feature.scope). Fix: animate a "
                + "change that comes from the database through `Observing(...).animation()`, and state that "
                + "never touches the database through TCA26's animated state change (G7)."
        )
    )
}
