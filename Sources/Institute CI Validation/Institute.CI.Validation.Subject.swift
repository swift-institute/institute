import struct Swift.String
public import Institute_Model
public import Institute_CI_Model
import GitHub_Standard
public import Institute_CI_Workflow

extension Institute.CI.Validation {
    /// The repository a rule is asked about: its reporting name and its
    /// checked-out root.
    ///
    /// `repository` is the `owner/name` string findings cite; `root` is
    /// where the bytes are. They are separate because they diverge in
    /// every real invocation — a sweep checks out `swift-primitives/…`
    /// into a scratch path, and the fixture corpus reports
    /// `swift-institute-test/<fixture>` for a directory under `tests/`.
    ///
    /// Discovery lives here rather than in each rule so fifty validators
    /// share one definition of "the workflows of this repository",
    /// including its ordering.
    public struct Subject: Sendable, Equatable {
        public let repository: String
        public let root: String

        public init(repository: String, root: String) {
            self.repository = repository
            self.root = root
        }

        /// A path inside the subject.
        public func path(_ relative: String) -> String {
            relative.isEmpty ? root : "\(root)/\(relative)"
        }

        /// The text of a file inside the subject, or `nil` when it does
        /// not exist.
        ///
        /// Absence is `nil`, not a defect: "this repository has no
        /// `.gitignore`" is a question rules legitimately ask. A file
        /// that exists and cannot be decoded *is* a defect.
        public func text(at relative: String) throws(EnvironmentDefect) -> String? {
            let path = path(relative)
            guard Institute.CI.Validation.exists(path) else { return nil }
            guard let text = Institute.CI.Validation.text(at: path) else {
                throw EnvironmentDefect.unreadableFile(path: path)
            }
            return text
        }

        /// Every workflow file under `.github/workflows/`, in the order
        /// the retired corpus used: `.yml` and `.yaml` gathered together
        /// and sorted by full path.
        ///
        /// The ordering is contractual. Findings are emitted in
        /// discovery order, and the differential gate compares against a
        /// Python implementation that sorted the same way.
        public func workflowPaths() throws(EnvironmentDefect) -> [String] {
            let directory = path(".github/workflows")
                        guard Institute.CI.Validation.isDirectory(directory)
            else { return [] }
            guard let names = Institute.CI.Validation.names(at: directory) else {
                throw EnvironmentDefect.unreadableFile(path: directory)
            }
            return names
                .filter { $0.hasSuffix(".yml") || $0.hasSuffix(".yaml") }
                .map { "\(directory)/\($0)" }
                .sorted()
        }

        /// Every workflow file, read.
        ///
        /// A document the reader refuses is surfaced as a `Finding`
        /// against `rule`, not as a defect — matching
        /// `load_workflow_yaml_or_emit`, which reported a parse failure
        /// as a violation of the rule being checked. Refusals and
        /// documents are returned together so a rule sees both in one
        /// pass.
        public func workflows(
            citing rule: Rule
        ) throws(EnvironmentDefect) -> (documents: [Institute.CI.Workflow.Document], refusals: [Finding]) {
            var documents: [Institute.CI.Workflow.Document] = []
            var refusals: [Finding] = []
            for path in try workflowPaths() {
                guard let text = Institute.CI.Validation.text(at: path) else {
                    throw EnvironmentDefect.unreadableFile(path: path)
                }
                let name = path.split(separator: "/").last.map(String.init) ?? path
                do {
                    documents.append(
                        try Institute.CI.Workflow.Document(
                            name: name, text: text))
                } catch {
                    refusals.append(
                        Finding(
                            repository: repository, rule: rule,
                            message: "\(name): YAML parse failed: \(error.message)"))
                }
            }
            return (documents, refusals)
        }
    }
}
