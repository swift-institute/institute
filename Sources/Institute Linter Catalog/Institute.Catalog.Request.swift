public import Institute_Model

extension Institute.Catalog {
    /// What a runner is asked to print after `--catalog`: the rules of a baked bundle, for one kind of file or all.
    public struct Request: Sendable, Equatable {
        public let bundle: Swift::String
        public let kind: Institute.Source.Kind?

        public init(bundle: Swift::String, kind: Institute.Source.Kind? = nil) {
            self.bundle = bundle
            self.kind = kind
        }
    }
}

extension Institute.Catalog.Request {
    public static let usage: Swift::String =
        "usage: \(Institute.Catalog.option) <bundle> ["
        + Institute.Source.Kind.allCases.map { "\($0)" }.joined(separator: " | ") + "]"

    /// The request the arguments after `--catalog` make; the usage, as a configuration error, when they make none.
    public init(arguments: [Swift::String]) throws(Institute.Error) {
        guard let bundle = arguments.first, !bundle.isEmpty, arguments.count <= 2 else {
            throw .configuration(Self.usage)
        }
        guard arguments.count == 2 else {
            self.init(bundle: bundle)
            return
        }
        guard let kind = Institute.Source.Kind(rawValue: arguments[1]) else {
            throw .configuration("unknown kind of file '\(arguments[1])'; \(Self.usage)")
        }
        self.init(bundle: bundle, kind: kind)
    }
}
