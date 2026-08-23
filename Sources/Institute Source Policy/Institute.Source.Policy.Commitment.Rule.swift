public import Institute_Model

extension Institute.Source.Policy.Commitment {
    public struct Rule: Sendable {
        public let suffix: Swift.String

        public init(suffix: Swift.String) {
            self.suffix = suffix
        }
    }
}
