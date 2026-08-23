import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import ContinuousIntegration

extension ContinuousIntegration.Validation {
    /// Rule identifier → validator, for the Institute-policy validators.
    ///
    /// The Institute's own registry: the corpus-and-convention
    /// validators this package owns. The seventeen GitHub-Actions-
    /// mechanics validators live with their subject in
    /// `GitHub.ContinuousIntegration.Validation.Registry`
    /// (swift-foundations/swift-github-continuous-integration); the two
    /// registries partition the retired shared registry without overlap.
    ///
    /// A validator declares its own rules and the index is derived, so a
    /// rule cannot be registered against one spelling and reported under
    /// another. Adding a validator means adding one line to `validators`
    /// and nothing else. Keep the list sorted by type name to make the
    /// conflict resolution mechanical.
    public enum Registry {
        // swiftlint:disable:next no_any_protocol_existential - heterogeneous registry over the externally owned Validator protocol; deliberate dynamic dispatch, the [API-ERR-006]-extension opt-out class (Wave 2b decision 3)
        public static let validators: [any Validator] = [
            Anchor(),
            ControlHost(),
            Gitignore(),
            ManifestBinding(),
            Readme(),
            SchemaCorrespondence(),
            SkillHygiene(),
            UniversalWorkflow(),
        ]

        // swiftlint:disable no_any_protocol_existential - selects one member of the heterogeneous registry above; same [API-ERR-006]-extension opt-out (Wave 2b decision 3)

        /// The validator authoritative for a rule, or `nil` when the rule
        /// has no Institute owner.
        public static func validator(for rule: Rule) -> (any Validator)? {
            validators.first { $0.rules.contains(rule) }
        }

        /// Every registered rule, sorted.
        public static var rules: [Rule] {
            validators.flatMap(\.rules).sorted()
        }

        /// The rule a fixture-corpus directory names.
        ///
        /// The corpus spells identifiers in lower case (`gh-ignore-001`,
        /// `skill-frontmatter`) while findings cite the registered
        /// spelling. Case-insensitive matching against the registry
        /// replaces the hand-maintained `prefix_for` table, so the two
        /// spellings cannot drift apart.
        public static func rule(forCorpusDirectory directory: String) -> Rule? {
            rules.first { $0.rawValue.lowercased() == directory.lowercased() }
        }

        // swiftlint:enable no_any_protocol_existential
    }
}
