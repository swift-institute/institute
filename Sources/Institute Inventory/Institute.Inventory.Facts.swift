public import Institute_Model

extension Institute.Inventory {
    /// What one Swift source file declares, imports and names.
    public struct Facts: Sendable {
        public var lines: Swift.Int = 0
        public var imports: [Import] = []
        public var types: [Declaration] = []
        public var extensions: [Extension] = []
        public var references: [Reference] = []
        public var members: [Symbol] = []
        /// How often each member name is used: `name` for an access,
        /// `name(a:_:)` for a call, labels as the call site writes them.
        public var uses: [Swift.String: Swift.Int] = [:]

        public init() {}
    }
}
