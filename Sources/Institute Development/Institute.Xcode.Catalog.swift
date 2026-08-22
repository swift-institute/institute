public import Institute_Model

extension Institute.Xcode {
    public struct Catalog: Sendable {
        public let entries: [Entry]

        public init(entries: [Entry]) {
            self.entries = entries
        }
    }
}
