internal import Institute_Development
internal import Institute_Inventory
internal import Institute_Lint
public import Institute_Model
internal import Institute_Pages

extension Institute.Doctor.Uniqueness {
    /// One repository's declared names: the library products and
    /// buildable targets its evaluated manifest contributes to the
    /// composed graph's two namespaces.
    public struct Declaration: Equatable, Sendable {
        public let repository: Swift.String
        public let products: [Swift.String]
        public let targets: [Swift.String]

        public init(
            repository: Swift.String,
            products: [Swift.String],
            targets: [Swift.String]
        ) {
            self.repository = repository
            self.products = products
            self.targets = targets
        }
    }
}
