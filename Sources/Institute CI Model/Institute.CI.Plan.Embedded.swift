public import Institute_Model

extension Institute.CI.Plan {
    /// The package closure selected for the advisory Embedded leg.
    ///
    /// Absence is an admission decision, not an empty target name. An
    /// admitted package either builds its whole package or one named target.
    public enum Embedded: Sendable, Equatable {
        case absent
        case package
        case target(String)

        public var target: String? {
            switch self {
            case .absent, .package: nil
            case let .target(name): name
            }
        }

        public var admitted: Bool {
            switch self {
            case .absent: false
            case .package, .target: true
            }
        }
    }
}
