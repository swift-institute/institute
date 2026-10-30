public import Institute_Model

extension Institute.Source.Policy {
    public struct Commitment: Sendable {
        public let repositories: [Swift.String]
        public let controls: [Swift.String]
        public let rule: Rule

        public init(
            repositories: [Swift.String],
            controls: [Swift.String],
            rule: Rule
        ) {
            self.repositories = repositories
            self.controls = controls
            self.rule = rule
        }
    }
}
