public import Institute_CI_Model
public import Institute_Model

import struct Swift.String

extension Institute.CI.Validation.BranchPins {
    /// The organizations whose dependency URLs `[BRANCH-PIN-001]` judges.
    ///
    /// The rule is scoped to dependencies on *Institute* URLs, so it
    /// cannot be evaluated without knowing which GitHub organizations are
    /// the Institute's. The answer has one owner, `Institute.Organization`;
    /// this set is that roster, never a second copy of it.
    public struct Organizations: Sendable, Equatable {
        public let names: Set<String>

        public init(names: Set<String>) {
            self.names = names
        }

        /// Every organization of `Institute.Organization`.
        public static let institute = Self(names: Set(Institute.Organization.allCases.map(\.rawValue)))

        public func contains(_ name: String) -> Bool { names.contains(name) }
    }
}
