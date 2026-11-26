public import Institute_Model
public import Lint

extension Institute.Catalog {
    /// Code a rule passes: a control of the rule that expects no finding, at the path the rule reads it at.
    public struct Example: Sendable, Equatable {
        public let path: Lint.Source.Path
        public let source: Swift::String
        /// The other files of the package the rule reads `source` with, by package-relative path.
        public let files: [Swift::String: Swift::String]
        /// What else the rule reads the package to hold: its license, its documents and its nested packages.
        public let facts: [Swift::String]

        public init(
            path: Lint.Source.Path,
            source: Swift::String,
            files: [Swift::String: Swift::String] = [:],
            facts: [Swift::String] = []
        ) {
            self.path = path
            self.source = source
            self.files = files
            self.facts = facts
        }
    }
}

extension Institute.Catalog.Example {
    public init(_ control: Lint.Rule.Control) {
        var facts: [Swift::String] = []
        switch control.license {
        case .unread: break
        case .absent: facts.append("no LICENSE file")
        case .text(let text):
            let first = text.split(separator: "\n", omittingEmptySubsequences: true).first.map { Swift::String($0) }
            facts.append("a LICENSE file that begins: \(first?.trimmingPrefix(while: \.isWhitespace) ?? "")")
        }
        facts += control.documents.sorted().map { "the document \($0)" }
        facts += control.packages.sorted().map { "the nested package \($0)" }
        self.init(path: control.path, source: control.source, files: control.files, facts: facts)
    }

    /// The kind of file the example is.
    public var kind: Institute.Source.Kind { Institute.Catalog.kind(of: path) }
}
