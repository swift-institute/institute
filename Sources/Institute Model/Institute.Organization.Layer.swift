extension Institute.Organization {
    public enum Layer: Swift.Int, Swift.CaseIterable, Swift.Comparable, Swift.Sendable {
        case atoms = 1
        case molecules
        case standards
        case compositions
        case control

        public static func < (lhs: Self, rhs: Self) -> Swift.Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}
