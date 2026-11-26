public import Institute_Model
public import Lint

extension Institute {
    /// The catalog of lint rules a writer reads before the lint runs: every enabled rule of a bundle, with the sentence the rule gives a
    /// finding with and code the rule passes.
    ///
    /// Each entry is made by running the rule on its own controls, as a lint run does before it reads a package: the
    /// statement is the message of a finding on a control that expects findings, and an example is a control that
    /// expects none and gives none. Nothing here is written a second time, so the catalog of a bundle cannot say
    /// another thing than a lint with that bundle does.
    public struct Catalog: Sendable, Equatable {
        public let entries: [Entry]

        public init(_ bundle: [Lint.Rule.Configuration]) {
            self.entries =
                bundle
                .filter { $0.mode == .enabled }
                .map(Entry.init(_:))
                .sorted { $0.id.underlying < $1.id.underlying }
        }
    }
}

extension Institute.Catalog {
    /// The leading argument that asks a runner for its catalog in place of a lint run.
    public static let option: Swift::String = "--catalog"

    /// The entries a writer of a file of `kind` reads: every entry when it is `nil`.
    public func entries(for kind: Institute.Source.Kind?) -> [Entry] {
        guard let kind else { return entries }
        return entries.filter { $0.kinds.contains(kind) }
    }

    /// The line that heads the catalog of `bundle`: how many rules it has, and how many of them `kind` leaves.
    public func summary(of bundle: Swift::String, for kind: Institute.Source.Kind? = nil) -> Swift::String {
        guard let kind else { return "bundle \(bundle): \(entries.count) rules" }
        let kept = entries(for: kind)
        return "bundle \(bundle): \(kept.count) of \(entries.count) rules give findings in a \(kind) file; "
            + "the \(kept.count { $0.written.contains(kind) }) written for one come first"
    }

    /// The lines the catalog is read as, for a file of `kind` or for every kind when it is `nil`: for each rule its
    /// id, severity and citation, the kinds of file it gives findings in, its statement, and one example it passes,
    /// one of `kind` when the rule has one. With a kind, the rules whose own controls are files of that kind come
    /// first, and after them the rules written for another kind of file that give findings in this one too.
    public func lines(for kind: Institute.Source.Kind? = nil) -> [Swift::String] {
        guard let kind else { return entries.flatMap { Self.lines($0, preferring: nil) } }
        let kept = entries(for: kind)
        let own = kept.filter { $0.written.contains(kind) }
        let other = kept.filter { !$0.written.contains(kind) }
        var lines: [Swift::String] = []
        if !own.isEmpty {
            lines += ["== \(own.count) rules written for a \(kind) file", ""]
            lines += own.flatMap { Self.lines($0, preferring: kind) }
        }
        if !other.isEmpty {
            lines += [
                "== \(other.count) rules written for another kind of file that give findings in a \(kind) file too",
                "",
            ]
            lines += other.flatMap { Self.lines($0, preferring: kind) }
        }
        return lines
    }

    private static func lines(_ entry: Entry, preferring kind: Institute.Source.Kind?) -> [Swift::String] {
        let head = "\(entry.id.underlying) (\(entry.severity))" + (entry.citation.map { " \($0)" } ?? "")
        guard entry.applies else {
            return [head, "  not in this repository: the rule is inapplicable to every one of its controls here", ""]
        }
        var lines = [
            head,
            "  in: " + entry.kinds.map { "\($0)" }.sorted().joined(separator: ", "),
            "  rule: "
                + (entry.statement ?? "not stated: no control of the rule gives a finding to take the sentence from"),
        ]
        guard let example = entry.examples.first(where: { $0.kind == kind }) ?? entry.examples.first else {
            return lines + ["  passes: no example: the rule has no control that expects a clean result", ""]
        }
        lines.append("  passes, as \(example.path.underlying):")
        lines += indented(example.source)
        for path in example.files.keys.sorted() {
            lines.append("  with \(path):")
            lines += indented(example.files[path] ?? "")
        }
        return lines + example.facts.map { "  with \($0)" } + [""]
    }

    private static func indented(_ source: Swift::String) -> [Swift::String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map { $0.isEmpty ? "" : "      \($0)" }
    }
}

extension Institute.Catalog {
    /// The kind of the file at `path` in a package: `Package.swift` and its version-specific forms are a manifest, a
    /// file under a `Tests` directory is a test, and any other file is a source file.
    static func kind(of path: Lint.Source.Path) -> Institute.Source.Kind {
        let components = path.underlying.split(separator: "/", omittingEmptySubsequences: true)
        let name = components.last ?? ""
        return if name == "Package.swift" || (name.hasPrefix("Package@swift-") && name.hasSuffix(".swift")) {
            .manifest
        } else if components.dropLast().contains("Tests") {
            .test
        } else {
            .source
        }
    }

    /// Where the file at `path` would be if it were of `kind`: the same file under the other of `Sources` and
    /// `Tests`, or the manifest.
    static func relocating(_ path: Lint.Source.Path, to kind: Institute.Source.Kind) -> Lint.Source.Path {
        let own = Self.kind(of: path)
        guard own != kind else { return path }
        switch (own, kind) {
        case (_, .manifest): return "Package.swift"
        case (.manifest, .source): return "Sources/Control/Control.swift"
        case (.manifest, .test): return "Tests/Control Tests/Control Tests.swift"
        default:
            let from: Swift::Substring = kind == .test ? "Sources" : "Tests"
            let to: Swift::Substring = kind == .test ? "Tests" : "Sources"
            var components = path.underlying.split(separator: "/", omittingEmptySubsequences: true)
            if let index = components.firstIndex(of: from) {
                components[index] = to
            } else {
                components.insert(to, at: 0)
            }
            return .init(components.joined(separator: "/"))
        }
    }
}
