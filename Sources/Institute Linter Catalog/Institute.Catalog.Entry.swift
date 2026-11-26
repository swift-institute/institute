internal import Byte
public import Institute_Model
public import Lint
internal import SwiftParser
internal import SwiftSyntax

extension Institute.Catalog {
    public struct Entry: Sendable, Equatable {
        public let id: Lint.Rule.ID
        public let severity: Diagnostic.Severity
        /// The message of a finding of the rule on one of its own controls; `nil` when no control gives one.
        public let message: Swift::String?
        /// Whether the rule observes anything in this repository: `false` when every control of the rule is one the
        /// rule is inapplicable to, as a rule placed in another layer's repository is.
        public let applies: Swift::Bool
        /// The kinds of file the rule's controls that give findings are written as; of its examples, when none does.
        public let written: Swift::Set<Institute.Source.Kind>
        /// The kinds of file a control of the rule gives a finding in, where it is and moved to each other kind.
        public let kinds: Swift::Set<Institute.Source.Kind>
        /// The controls that expect no finding and give none, the plainest first: before any other, the ones whose
        /// source no control with findings shares, which pass for what they are and not for where they are; then the
        /// ones read with no license, document or nested package; then the ones of a kind the rule is written for.
        public let examples: [Example]

        public init(
            id: Lint.Rule.ID,
            severity: Diagnostic.Severity,
            message: Swift::String?,
            applies: Swift::Bool = true,
            written: Swift::Set<Institute.Source.Kind>,
            kinds: Swift::Set<Institute.Source.Kind>,
            examples: [Example]
        ) {
            self.applies = applies
            self.written = written
            self.id = id
            self.severity = severity
            self.message = message
            self.kinds = kinds
            self.examples = examples
        }
    }
}

extension Institute.Catalog.Entry {
    public init(_ configuration: Lint.Rule.Configuration) {
        let rule = configuration.rule
        let severity = configuration.severity ?? rule.severity.default
        var message: Swift::String?
        var written: Swift::Set<Institute.Source.Kind> = []
        var kinds: Swift::Set<Institute.Source.Kind> = []
        var examples: [Institute.Catalog.Example] = []
        let flagged = Swift::Set(rule.controls.filter { $0.expectation.count > 0 }.map(\.source))
        for control in rule.controls where control.applicability.isApplicable {
            let found = Self.observe(control, at: control.path, with: rule, severity: severity)
            guard control.expectation.count > 0 else {
                if found.findings.isEmpty, found.applicability.isApplicable {
                    examples.append(.init(control))
                }
                continue
            }
            guard let first = found.findings.first else { continue }
            message = message ?? first.message
            let own = Institute.Catalog.kind(of: control.path)
            written.insert(own)
            kinds.insert(own)
            for kind in Institute.Source.Kind.allCases where !kinds.contains(kind) {
                let moved = Self.observe(
                    control,
                    at: Institute.Catalog.relocating(control.path, to: kind),
                    with: rule,
                    severity: severity
                )
                if !moved.findings.isEmpty, moved.applicability.isApplicable { kinds.insert(kind) }
            }
        }
        let rank = { (example: Institute.Catalog.Example) -> Swift::Int in
            (flagged.contains(example.source) ? 4 : 0) + (example.facts.isEmpty ? 0 : 2)
                + (written.isEmpty || written.contains(example.kind) ? 0 : 1)
        }
        examples = examples.enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
        if written.isEmpty {
            written = Swift::Set(examples.map(\.kind))
            kinds = written
        }
        self.init(
            id: rule.id,
            severity: severity,
            message: message,
            applies: rule.controls.contains { $0.applicability.isApplicable },
            written: written,
            kinds: kinds,
            examples: examples
        )
    }

    /// What `rule` observes in `control`, read at `path`, as a lint run evaluates a control.
    private static func observe(
        _ control: Lint.Rule.Control,
        at path: Lint.Source.Path,
        with rule: Lint.Rule,
        severity: Diagnostic.Severity
    ) -> Lint.Rule.Observation {
        let placed = Lint.Rule.Control(
            id: control.id,
            source: control.source,
            path: path,
            expectation: control.expectation,
            applicability: control.applicability,
            license: control.license,
            files: control.files,
            documents: control.documents,
            packages: control.packages
        )
        var manager = Source.Manager()
        let fileID = manager.register(
            fileID: path.underlying,
            filePath: path.underlying,
            content: [Byte](utf8: control.source)
        )
        let tree = Parser.parse(source: control.source)
        let parsed = Lint.Source.Parsed(
            file: manager.file(for: fileID),
            path: path,
            tree: tree,
            converter: SourceLocationConverter(fileName: path.underlying, tree: tree),
            types: Lint.Brand.types(in: tree),
            index: placed.index(tree: tree) { Parser.parse(source: $0) }
        )
        return rule.observe(parsed, severity)
    }
}

extension Institute.Catalog.Entry {
    /// The citation of the message, between the rule's bracketed id and the colon: the place the rule is argued.
    public var citation: Swift::String? { parts?.citation }

    /// The first sentence of the message, after its `[rule id] citation: ` head.
    public var statement: Swift::String? {
        guard let message else { return nil }
        return Self.sentence(parts?.description ?? message)
    }

    private var parts: (citation: Swift::String?, description: Swift::String)? {
        guard let message, message.hasPrefix("["), let close = message.firstIndex(of: "]") else { return nil }
        let tail = message[message.index(after: close)...]
        guard let colon = tail.firstRange(of: ": ") else { return nil }
        let citation = tail[..<colon.lowerBound].trimmingPrefix(while: \.isWhitespace)
        guard !citation.contains(where: \.isNewline), citation.count <= 80 else { return nil }
        return (citation.isEmpty ? nil : Swift::String(citation), Swift::String(tail[colon.upperBound...]))
    }

    /// `text` up to its first full stop that ends a sentence: one outside code and parentheses, not of an
    /// abbreviation, and followed by nothing or by a space and anything but a small letter.
    static func sentence(_ text: Swift::String) -> Swift::String {
        let characters = Swift::Array(text)
        var code = false
        var depth = 0
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "`" { code.toggle() }
            if !code {
                if character == "(" { depth += 1 }
                if character == ")", depth > 0 { depth -= 1 }
                if character == ".", depth == 0 {
                    var next = index + 1
                    while next < characters.count, characters[next].isWhitespace { next += 1 }
                    let ends = next == characters.count || (next > index + 1 && !characters[next].isLowercase)
                    var start = index
                    while start > 0, characters[start - 1].isLetter || characters[start - 1] == "." { start -= 1 }
                    let word = Swift::String(characters[start..<index]).lowercased()
                    if ends, !["e.g", "i.e", "etc", "vs", "cf"].contains(word) {
                        return Swift::String(characters[...index])
                    }
                }
            }
            index += 1
        }
        return text
    }
}
