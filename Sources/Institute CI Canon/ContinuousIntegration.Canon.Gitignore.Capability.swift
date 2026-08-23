import Institute_CI_Model

extension ContinuousIntegration.Canon.Gitignore {
    /// The complete semantic vocabulary that may widen generated ignore
    /// policy. New cases require a separate policy ruling.
    public enum Capability: String, CaseIterable, Sendable, Equatable {
        case benchmark = "benchmark baseline"
        case snapshot = "snapshot baseline"
        case environment = "environment example"
        case corpus = "repository policy corpus"
        case provenance = "fixture provenance manifest"
        case editor = "editor configuration"

        /// The exact admission owned by this semantic capability.
        public var admission: String {
            switch self {
            case .benchmark: "!**/.benchmarks/"
            case .snapshot: "!**/.snapshots/"
            case .environment: "!/.env.example"
            case .corpus: "!/canon/"
            case .provenance: "!**/Fixtures/MANIFEST.md"
            case .editor: "!/.editorconfig"
            }
        }

        /// The generated block shared by every repository class.
        public static var block: String {
            "# Closed semantic capability admissions\n"
                + allCases.map(\.admission).joined(separator: "\n") + "\n"
        }
    }
}
