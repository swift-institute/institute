import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Continuous_Integration_Workflow
import GitHub_Standard
import ContinuousIntegration

extension ContinuousIntegration.Validation {
    /// `[CI-CONTROL-001]` — the public control-plane repository retains
    /// its dispatch-only, exact-head validation host.
    ///
    /// The host is the public credential boundary through which the private
    /// Control binary acquires an untrusted candidate and publishes the
    /// `control / validate` result. Its absence must therefore be a finding,
    /// never an inapplicable or unmeasured check. Other repositories do not
    /// own this organization-level host and are deliberately out of scope.
    public struct ControlHost: Validator {
        public let rules: [Rule] = ["CI-CONTROL-001"]

        public static let canonicalRepository = "swift-institute/.github"
        public static let workflowPath = ".github/workflows/control-validate.yml"

        public init() {}

        public func findings(in subject: Subject) throws(EnvironmentDefect) -> [Finding] {
            guard subject.repository == Self.canonicalRepository else { return [] }
            guard let text = try subject.text(at: Self.workflowPath) else {
                return [finding(subject.repository, "trusted Control host is absent")]
            }

            let document: GitHub.ContinuousIntegration.Workflow.Document
            do throws(GitHub.ContinuousIntegration.Workflow.YAML.Error) {
                document = try .init(name: "control-validate.yml", text: text)
            } catch {
                return [finding(subject.repository, "YAML parse failed: \(error.message)")]
            }

            var result: [Finding] = []
            let triggers = document.triggers
            let triggerNames = Set(triggers?.textKeys ?? [])
            if triggerNames != ["workflow_dispatch"] {
                result.append(
                    finding(
                        subject.repository,
                        "trusted Control host must be dispatch-only"
                    )
                )
            }

            let inputs = triggers?["workflow_dispatch"]?["inputs"]?.mapping
            for name in ["repository", "pull", "head"] {
                guard let input = inputs?[name]?.mapping,
                    input["required"]?.boolean == true
                else {
                    result.append(
                        finding(
                            subject.repository,
                            "workflow_dispatch input `\(name)` must exist and be required"
                        )
                    )
                    continue
                }
            }

            if document.body?["permissions"]?.mapping?.entries.isEmpty != true {
                result.append(
                    finding(
                        subject.repository,
                        "trusted Control host must deny top-level permissions with `permissions: {}`"
                    )
                )
            }
            if document.body?["jobs"]?["control"]?.mapping == nil {
                result.append(
                    finding(subject.repository, "trusted Control host has no `control` job")
                )
            }
            return result
        }

        private func finding(_ repository: String, _ message: String) -> Finding {
            Finding(repository: repository, rule: rules[0], message: message)
        }
    }
}
