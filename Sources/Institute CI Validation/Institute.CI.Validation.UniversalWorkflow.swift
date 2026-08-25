import struct Swift.String
public import Institute_Model
public import Institute_CI_Model
public import Institute_CI_Workflow
import GitHub_Standard

extension Institute.CI.Validation {
    /// The Institute policy over the planner-driven universal workflow.
    ///
    /// Generic workflow parsing remains with GitHub Continuous Integration.
    /// This validator owns the Institute's leg catalogue, Windows posture,
    /// and the correspondence between planner-selected gating legs and the
    /// terminal aggregate.
    public struct UniversalWorkflow: Validator {
        public let rules: [Rule] = ["CI-010", "CI-099"]

        public init() {}

        public static let canonicalRepository = "swift-institute/.github"

        /// Every job the planner can select, plus its two orchestration jobs.
        public static let catalogue: [String] = [
            "plan",
            "linux-release", "linux-6-4", "linux-nightly",
            "embedded", "embedded-wasm-sdk", "android-build",
            "static-linux-musl-build", "macos-release",
            "apple-simulator-build", "windows-release",
            "source", "advisory-summary", "ci-ok",
        ]

        public static let gating: [String] = [
            "linux-release", "macos-release", "windows-release",
            "source",
        ]

        public func findings(in subject: Subject) throws(EnvironmentDefect) -> [Finding] {
            guard
                subject.repository == Self.canonicalRepository
                    || subject.repository.contains("-test/")
            else { return [] }
            guard let text = try subject.text(at: ".github/workflows/swift-ci.yml") else {
                return [finding(subject.repository, "CI-010", "universal workflow is absent")]
            }

            let document: Institute.CI.Workflow.Document
            do throws(Institute.CI.Workflow.YAML.Error) {
                document = try .init(name: "swift-ci.yml", text: text)
            } catch {
                return [
                    finding(
                        subject.repository,
                        "CI-010",
                        "YAML parse failed: \(error.message)"
                    )
                ]
            }
            guard let jobs = document.body?["jobs"]?.mapping else {
                return [finding(subject.repository, "CI-010", "workflow has no jobs mapping")]
            }

            var result: [Finding] = []
            for retired in ["format", "lint", "swift-linter"] where jobs[retired] != nil {
                result.append(
                    finding(
                        subject.repository,
                        "CI-010",
                        "retired source job `\(retired)` is still present"
                    )
                )
            }
            for name in Self.catalogue where jobs[name]?.mapping == nil {
                result.append(
                    finding(
                        subject.repository,
                        "CI-010",
                        "planner catalogue job `\(name)` is absent"
                    )
                )
            }

            guard let windows = jobs["windows-release"]?.mapping else { return result }
            if windows["continue-on-error"]?.boolean == true {
                result.append(
                    finding(subject.repository, "CI-099", "Windows must never be advisory")
                )
            }
            if !(windows["runs-on"]?.text ?? "").lowercased().contains("windows") {
                result.append(
                    finding(subject.repository, "CI-010", "Windows must use a Windows runner")
                )
            }

            let aggregateNeeds = Set(Self.names(in: jobs["ci-ok"]?["needs"]))
            let expectedAggregateNeeds = Set(["plan"] + Self.gating)
            for name in expectedAggregateNeeds.subtracting(aggregateNeeds).sorted() {
                result.append(
                    finding(
                        subject.repository,
                        "CI-010",
                        "ci-ok does not consume gating result `\(name)`"
                    )
                )
            }
            for name in aggregateNeeds.subtracting(expectedAggregateNeeds).sorted() {
                result.append(
                    finding(
                        subject.repository,
                        "CI-010",
                        "ci-ok consumes non-gating result `\(name)`"
                    )
                )
            }

            let advisoryNeeds = Set(Self.names(in: jobs["advisory-summary"]?["needs"]))
            for name in Set(Self.gating).intersection(advisoryNeeds).sorted() {
                result.append(
                    finding(
                        subject.repository,
                        "CI-099",
                        "gating result `\(name)` is routed to the advisory set"
                    )
                )
            }

            for name in Self.gating {
                guard let body = jobs[name]?.mapping else { continue }
                if body["continue-on-error"]?.boolean == true {
                    result.append(
                        finding(
                            subject.repository,
                            "CI-099",
                            "gating job `\(name)` is advisory"
                        )
                    )
                }
                let condition = body["if"]?.text ?? ""
                let selected = "needs.plan.outputs.legs"
                if !condition.contains(selected) || !condition.contains("',\(name),'") {
                    result.append(
                        finding(
                            subject.repository,
                            "CI-010",
                            "gating job `\(name)` is not selected by the planner leg catalogue"
                        )
                    )
                }
            }
            return result
        }

        private func finding(_ repository: String, _ rule: Rule, _ message: String) -> Finding {
            Finding(repository: repository, rule: rule, message: message)
        }

        private static func names(
            in node: Institute.CI.Workflow.YAML.Node?
        ) -> [String] {
            if let text = node?.text { return [text] }
            return node?.sequence?.compactMap(\.text) ?? []
        }
    }
}
