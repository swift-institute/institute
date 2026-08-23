import struct Swift.String
public import Institute_CI_Model
public import Institute_Model

extension Institute.CI.Validation {
    /// Rule identifier → validator.
    ///
    /// The one registry of the reabsorbed validation surface: the
    /// GitHub-Actions-mechanics validators that came home with the
    /// engine contract and the Institute's own corpus-and-convention
    /// validators. The retired shared registry was partitioned across
    /// two packages; reabsorption reunifies it, so a rule cannot be
    /// registered against one spelling and reported under another, and
    /// no rule has two owners.
    ///
    /// A validator declares its own rules and the index is derived.
    /// Adding a validator means adding one line to `validators` and
    /// nothing else. Keep the list sorted by type name to make the
    /// conflict resolution mechanical.
    public enum Registry {
        // swiftlint:disable:next no_any_protocol_existential - heterogeneous registry over the Validator protocol; deliberate dynamic dispatch, the [API-ERR-006]-extension opt-out class (Wave 2b decision 3)
        public static let validators: [any Validator] = [
            Anchor(),
            BinaryInstallChecksum(),
            BranchPins(),
            CachePolicy(),
            CompositeActionDescriptions(),
            CompositeActionPins(),
            ContinueOnError(),
            ControlHost(),
            Drift.LintValidatorsWeekly(),
            Drift.ScheduledWorkflowAlert(),
            EmbeddedJob(),
            EnvironmentContext(),
            Gitignore(),
            HardenRunner(),
            InputDefaults(),
            ManifestBinding(),
            PermissionsShape(),
            Readme(),
            SchemaCorrespondence(),
            SkillHygiene(),
            SubOrgWrappers(),
            ThinCallers(),
            UniversalWorkflow(),
            VisibilityGate(),
        ]

        // swiftlint:disable no_any_protocol_existential - selects one member of the heterogeneous registry above; same [API-ERR-006]-extension opt-out (Wave 2b decision 3)

        /// The validator authoritative for a rule, or `nil` when the rule
        /// has no owner.
        public static func validator(for rule: Rule) -> (any Validator)? {
            validators.first { $0.rules.contains(rule) }
        }

        /// Every registered rule, sorted.
        public static var rules: [Rule] {
            validators.flatMap(\.rules).sorted()
        }

        /// The rule a fixture-corpus directory names.
        ///
        /// The corpus spells identifiers in lower case (`ci-105`,
        /// `gh-ignore-001`, `skill-frontmatter`) while findings cite the
        /// registered spelling. Case-insensitive matching against the
        /// registry replaces the hand-maintained `prefix_for` table, so
        /// the two spellings cannot drift apart.
        public static func rule(forCorpusDirectory directory: String) -> Rule? {
            rules.first { $0.rawValue.lowercased() == directory.lowercased() }
        }

        // swiftlint:enable no_any_protocol_existential
    }
}
