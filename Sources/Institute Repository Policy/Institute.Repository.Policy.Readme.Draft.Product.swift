public import Institute_Model

extension Institute.Repository.Policy.Readme.Draft {
    public struct Product: Sendable, Equatable {
        public let name: Swift.String
        public let targets: [Swift.String]

        public init(name: Swift.String, targets: [Swift.String]) {
            self.name = name
            self.targets = targets
        }
    }
}
