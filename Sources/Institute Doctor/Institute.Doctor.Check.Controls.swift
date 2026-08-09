public import Institute_Model
internal import Institute_Inventory
internal import Institute_Pages
internal import Institute_Development
internal import Institute_Lint

extension Institute.Doctor.Check {
    /// A check's declared controls: a known-positive subject the
    /// evaluation must fire on, and a known-negative it must not.
    public struct Controls: Sendable {
        public let positive: Subject
        public let negative: Subject

        public init(positive: Subject, negative: Subject) {
            self.positive = positive
            self.negative = negative
        }
    }
}
