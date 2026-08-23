import Foundation
import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import ContinuousIntegration

extension ContinuousIntegration {
    /// Deterministic validation of an untrusted control-plane checkout.
    public enum Control {}
}

extension ContinuousIntegration.Control {
    public enum Validation {
        // The compositor intentionally runs heterogeneous canonical validators.
        // swiftlint:disable:next no_any_protocol_existential
        private static let mechanics: [any GitHub.ContinuousIntegration.Validation.Validator] = [
            GitHub.ContinuousIntegration.Validation.BinaryInstallChecksum(),
            GitHub.ContinuousIntegration.Validation.CachePolicy(),
            GitHub.ContinuousIntegration.Validation.CompositeActionDescriptions(),
            GitHub.ContinuousIntegration.Validation.CompositeActionPins(),
            GitHub.ContinuousIntegration.Validation.ContinueOnError(),
            GitHub.ContinuousIntegration.Validation.EmbeddedJob(),
            GitHub.ContinuousIntegration.Validation.EnvironmentContext(),
            GitHub.ContinuousIntegration.Validation.HardenRunner(),
            GitHub.ContinuousIntegration.Validation.InputDefaults(),
            GitHub.ContinuousIntegration.Validation.PermissionsShape(),
            GitHub.ContinuousIntegration.Validation.SubOrgWrappers(),
            GitHub.ContinuousIntegration.Validation.ThinCallers(),
            GitHub.ContinuousIntegration.Validation.VisibilityGate(),
        ]

        // The Institute-owned terminal control-plane predicates. Historical
        // correspondence checks do not become policy by proximity.
        // swiftlint:disable:next no_any_protocol_existential
        private static let institute: [any GitHub.ContinuousIntegration.Validation.Validator] = [
            ContinuousIntegration.Validation.Anchor(),
            ContinuousIntegration.Validation.ControlHost(),
            ContinuousIntegration.Validation.UniversalWorkflow(),
        ]

        /// Reads `root` strictly as data; it never executes candidate code, actions, or workflows.
        public static func run(
            repository: String,
            root: String
        ) -> GitHub.ContinuousIntegration.Validation.Run {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: root, isDirectory: &isDirectory),
                isDirectory.boolValue
            else {
                return .init(findings: [], defect: .unreadableSubject(root: root))
            }
            guard let entries = FileManager.default.enumerator(atPath: root),
                entries.nextObject() != nil
            else {
                return .init(findings: [], defect: .missingSupportFile(path: root))
            }

            let subject = GitHub.ContinuousIntegration.Validation.Subject(
                repository: repository,
                root: root
            )
            var findings: [GitHub.ContinuousIntegration.Validation.Finding] = []

            for validator in mechanics + institute {
                let run = GitHub.ContinuousIntegration.Validation.Run.validate(
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
