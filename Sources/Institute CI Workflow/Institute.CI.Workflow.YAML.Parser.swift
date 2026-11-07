import GitHub_Standard
public import Institute_CI_Model
public import Institute_Model

extension Institute.CI.Workflow.YAML {
    /// Reads a workflow document's text into a `Node`.
    ///
    /// Indentation-driven recursive descent over the block constructs
    /// Actions documents use, plus anchors and aliases on mapping values.
    /// Tags, explicit `? key` entries, multi-document streams, and
    /// anchors in positions the corpus does not use are **refused**
    /// rather than mis-read: guessing at an uncovered construct is how a
    /// bounded reader turns into a wrong general one, and a wrong
    /// document reaches a rule predicate looking entirely plausible.
    public struct Parser: Sendable {
        private let lines: [Line]
        private var cursor: Int = 0

        /// Anchor definitions seen so far. YAML anchors are rare in
        /// workflow documents but not absent — the fixture corpus carries
        /// one — and refusing them would make the reader stricter than
        /// the PyYAML it replaces, which is a behavioural change wearing
        /// a safety costume.
        private var anchors: [String: Node] = [:]

        public init(_ text: String) {
            self.lines = Line.scan(text)
        }

        /// Parse the whole document. An empty or comment-only document
        /// resolves to `.null`, matching `safe_load` returning `None`.
        public static func parse(_ text: String) throws(Error) -> Node {
            var parser = Parser(text)
            return try parser.document()
        }

        private mutating func document() throws(Error) -> Node {
            skipBlanks()
            if cursor < lines.count, lines[cursor].content == "---" {
                cursor += 1
                skipBlanks()
            }
            guard cursor < lines.count else { return .null }
            let node = try block(atLeast: 0)
            skipBlanks()
            guard cursor >= lines.count else {
                throw Error.unsupported(
                    line: lines[cursor].number,
                    construct: "trailing content after the document body"
                )
            }
            return node
        }

        private mutating func block(atLeast minimum: Int) throws(Error) -> Node {
            skipBlanks()
            guard cursor < lines.count, lines[cursor].indent >= minimum else { return .null }
            let indent = lines[cursor].indent
            return lines[cursor].isSequenceItem
                ? try sequence(at: indent)
                : try mapping(at: indent)
        }

        private mutating func sequence(at indent: Int) throws(Error) -> Node {
            var elements: [Node] = []
            while true {
                skipBlanks()
                guard cursor < lines.count,
                    lines[cursor].indent == indent,
                    lines[cursor].isSequenceItem
                else { break }

                let line = lines[cursor]
                let inline = line.sequenceItemContent
                if inline.isEmpty {
                    cursor += 1
                    elements.append(try block(atLeast: indent + 1))
                } else {
                    let column = line.indent + (line.content.count - inline.count)
                    cursor += 1
                    elements.append(try inlineItem(inline, column: column, of: line))
                }
            }
            return .sequence(elements)
        }

        /// The content that followed `- ` on the item line, plus any
        /// continuation lines indented to the same column.
        private mutating func inlineItem(
            _ inline: String,
            column: Int,
            of line: Line
        ) throws(Error) -> Node {
            if inline.hasPrefix("- ") || inline == "-" {
                throw Error.unsupported(
                    line: line.number,
                    construct: "a sequence nested inline in a sequence item"
                )
            }
            if inline.hasPrefix("&") {
                throw Error.unsupported(
                    line: line.number,
                    construct: "an anchor on a sequence item"
                )
            }
            guard let entry = Line.splitKey(inline) else {
                return try scalar(inline, on: line)
            }
            var entries: [Mapping.Entry] = []
            try appendEntry(entry, at: column, on: line, into: &entries)
            try appendEntries(at: column, into: &entries)
            return .mapping(Mapping(entries))
        }

        private mutating func mapping(at indent: Int) throws(Error) -> Node {
            var entries: [Mapping.Entry] = []
            try appendEntries(at: indent, into: &entries)
            guard !entries.isEmpty else {
                let line = lines[min(cursor, lines.count - 1)]
                throw Error.unsupported(
                    line: line.number,
                    construct: "a block node that is neither mapping nor sequence"
                )
            }
            return .mapping(Mapping(entries))
        }

        private mutating func appendEntries(
            at indent: Int,
            into entries: inout [Mapping.Entry]
        ) throws(Error) {
            while true {
                skipBlanks()
                guard cursor < lines.count,
                    lines[cursor].indent == indent,
                    !lines[cursor].isSequenceItem
                else { break }
                let line = lines[cursor]
                guard let entry = Line.splitKey(line.content) else {
                    throw Error.unsupported(
                        line: line.number,
                        construct: "a plain scalar where a mapping key was expected"
                    )
                }
                cursor += 1
                try appendEntry(entry, at: indent, on: line, into: &entries)
            }
        }

        private mutating func appendEntry(
            _ entry: (key: String, value: String),
            at indent: Int,
            on line: Line,
            into entries: inout [Mapping.Entry]
        ) throws(Error) {
            let key = try scalar(entry.key, on: line)
            let (anchor, value) = Self.detachAnchor(from: entry.value)

            defer {
                if let anchor, let node = entries.last?.value { anchors[anchor] = node }
            }

            if value.isEmpty {
                skipBlanks()
                if cursor < lines.count, lines[cursor].indent == indent, lines[cursor].isSequenceItem {
                    entries.append((key, try sequence(at: indent)))
                } else {
                    entries.append((key, try block(atLeast: indent + 1)))
                }
                return
            }

            if let indicator = BlockScalar.Indicator(value) {
                entries.append((key, .text(blockScalar(indicator, deeperThan: indent))))
                return
            }

            entries.append((key, try scalar(value, on: line)))
        }

        /// Split a leading `&anchor` off a node's inline text.
        static func detachAnchor(from value: String) -> (anchor: String?, rest: String) {
            guard value.hasPrefix("&") else { return (nil, value) }
            let body = value.dropFirst()
            let name = body.prefix { $0 != " " }
            let rest = body.dropFirst(name.count).drop { $0 == " " }
            return (String(name), String(rest))
        }

        private func scalar(_ text: String, on line: Line) throws(Error) -> Node {
            if text.hasPrefix("*") {
                let name = String(text.dropFirst())
                guard let node = anchors[name] else {
                    throw Error.unsupported(
                        line: line.number,
                        construct: "an alias to an undefined anchor '\(name)'"
                    )
                }
                return node
            }
            if text.hasPrefix("!") {
                throw Error.unsupported(line: line.number, construct: "explicit tags")
            }
            if text.hasPrefix("[") || text.hasPrefix("{") {
                var flow = Flow(text)
                return try flow.parse(on: line.number)
            }
            if let quoted = Line.unquote(text) { return .text(quoted) }
            return Resolver.resolve(text)
        }

        private mutating func blockScalar(
            _ indicator: BlockScalar.Indicator,
            deeperThan indent: Int
        ) -> String {
            var raw: [Line] = []
            while cursor < lines.count {
                let line = lines[cursor]
                if line.isEmpty {
                    raw.append(line)
                    cursor += 1
                    continue
                }
                guard line.indent > indent else { break }
                raw.append(line)
                cursor += 1
            }
            while let last = raw.last, last.isEmpty { raw.removeLast() }
            return BlockScalar.render(raw, indicator: indicator)
        }

        private mutating func skipBlanks() {
            while cursor < lines.count, lines[cursor].isSkippable { cursor += 1 }
        }
    }
}
