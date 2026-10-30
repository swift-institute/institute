public import Institute_Model

extension Institute.Planner.Canary {
    /// The canary's verdict and its exit code.
    public enum Verdict: Swift.String, Sendable, Equatable {
        /// At least one canary ran, every canary ran, and none regressed.
        case adoptable
        /// A canary regressed or did not run, or none was compared.
        case differs
        /// The contract or a verification refused before any comparison.
        case refused

        public init(_ comparisons: [Comparison]) {
            self =
                comparisons.isEmpty || comparisons.contains(where: \.isRegressed)
                ? .differs : .adoptable
        }

        public var code: Swift.Int32 {
            switch self {
            case .adoptable: 0
            case .differs: 1
            case .refused: 2
            }
        }
    }
}
