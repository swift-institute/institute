extension Repository.Policy.Caller.Wave {
    public struct RulesetReference: Sendable, Equatable {
        public let id: Int64
        public let name: String

        public init(id: Int64, name: String) {
            self.id = id
            self.name = name
        }
    }
}
