public import Institute_Architecture_Facts
public import Institute_Architecture_Graph
public import Institute_Architecture_Model
public import Institute_Model

extension Institute.Architecture.Validator {
    /// The outcome of one validation pass.
    public struct Report: Sendable, Equatable {
        /// The complete derived population this result validated.
        public let derived: Institute.Architecture.Facts
        /// The graph over ``derived`` this result validated.
        public let graph: Institute.Architecture.Graph
        /// Violations no valid exemption covers; any entry fails the run.
        public let violations: [Institute.Architecture.Violation]
        /// Violations an unexpired, scope- and owner-matching exemption
        /// covers.
        public let excused: [Institute.Architecture.Violation]
    }
}

extension Institute.Architecture.Validator.Report {
    public var passes: Swift.Bool {
        violations.isEmpty
    }
}
