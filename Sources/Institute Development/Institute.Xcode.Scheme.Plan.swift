extension Institute.Xcode.Scheme {
    public struct Plan: Sendable, Equatable {
        public let buildables: [Buildable]
        public let testables: [Testable]

        public init(buildables: [Buildable], testables: [Testable]) {
            self.buildables = buildables
            self.testables = testables
        }
    }
}
