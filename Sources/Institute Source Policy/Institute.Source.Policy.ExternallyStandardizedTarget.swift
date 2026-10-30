public import Institute_Model

extension Institute.Source.Policy {
    /// A package target whose public terminology is imposed by an external
    /// specification authority rather than invented by the package.
    public struct ExternallyStandardizedTarget: Hashable, Sendable {
        public let identity: Swift.String

        public init(_ identity: Swift.String) {
            self.identity = identity
        }

        public var sourceRoot: Swift.String {
            "Sources/\(identity)/"
        }
    }
}
