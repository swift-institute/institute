public import Institute_Model

extension Institute.Inventory {
    /// What one Swift source file declares, imports and names.
    public struct Facts: Sendable {
        public var lines: Swift.Int = 0
        public var imports: [Import] = []
        public var types: [Declaration] = []
        public var extensions: [Extension] = []
        public var references: [Reference] = []

        public init() {}
    }
}
