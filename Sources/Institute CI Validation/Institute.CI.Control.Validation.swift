import struct Swift.String
public import Institute_Model
public import Institute_CI_Model
import GitHub_Standard

extension Institute.CI {
    /// Deterministic validation of an untrusted control-plane checkout.
    public enum Control {}
}

extension Institute.CI.Control {
    public enum Validation {
        // The compositor intentionally runs heterogeneous canonical validators.
        // swiftlint:disable:next no_any_protocol_existential
        private static let mechanics: [any Institute.CI.Validation.Validator] = [
            Institute.CI.Validation.BinaryInstallChecksum(),
            Institute.CI.Validation.CachePolicy(),
            Institute.CI.Validation.CompositeActionDescriptions(),
            Institute.CI.Validation.CompositeActionPins(),
            Institute.CI.Validation.ContinueOnError(),
            Institute.CI.Validation.EmbeddedJob(),
            Institute.CI.Validation.EnvironmentContext(),
            Institute.CI.Validation.HardenRunner(),
            Institute.CI.Validation.InputDefaults(),
            Institute.CI.Validation.PermissionsShape(),
            Institute.CI.Validation.SubOrgWrappers(),
            Institute.CI.Validation.ThinCallers(),
            Institute.CI.Validation.VisibilityGate(),
        ]

        // The Institute-owned terminal control-plane predicates. Historical
        // correspondence checks do not become policy by proximity.
        // swiftlint:disable:next no_any_protocol_existential
        private static let institute: [any Institute.CI.Validation.Validator] = [
            Institute.CI.Validation.Anchor(),
            Institute.CI.Validation.ControlHost(),
            Institute.CI.Validation.UniversalWorkflow(),
        ]

        /// Reads `root` strictly as data; it never executes candidate code, actions, or workflows.
        public static func run(
            repository: String,
            root: String
        ) -> Institute.CI.Validation.Run {
                        guard Institute.CI.Validation.isDirectory(root)
            else {
                return .init(findings: [], defect: .unreadableSubject(root: root))
            }
            guard !Institute.CI.Validation.filesRecursively(at: root).isEmpty
            else {
                return .init(findings: [], defect: .missingSupportFile(path: root))
            }

            let subject = Institute.CI.Validation.Subject(
                repository: repository,
                root: root
            )
            var findings: [Institute.CI.Validation.Finding] = []

            for validator in mechanics + institute {
                let run = Institute.CI.Validation.Run.validate(
                    validator,
                    of: subject
                )
                if let defect = run.defect {
                    return .init(findings: findings.sorted(), defect: defect)
                }
                findings += run.findings
            }
            return .init(findings: findings.sorted())
        }
    }
}
