extension Institute.Xcode.Scheme {
    public struct Testable: Sendable, Equatable {
        public let reference: Swift.String
        public let target: Swift.String

        public init(reference: Swift.String, target: Swift.String) {
            self.reference = reference
            self.target = target
        }
    }
}
