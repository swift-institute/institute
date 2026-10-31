public import Lint

extension Lint.SQL {

    public struct Exceptions: Sendable, Hashable, ExpressibleByArrayLiteral {

        public let entries: [Exception]

        public init(_ entries: [Exception]) {
            self.entries = entries
        }

        public init(arrayLiteral entries: Exception...) {
            self.entries = entries
        }
    }
}

extension Lint.SQL.Exceptions {

    public static let none: Self = []

    package func entries(in file: Swift::String) -> [Lint.SQL.Exception] {
        entries.filter { $0.file == file }
    }
}
