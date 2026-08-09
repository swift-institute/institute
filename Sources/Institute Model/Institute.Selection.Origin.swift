extension Institute.Selection {
    /// Which selection is in effect for this checkout, and how it was formed.
    ///
    /// The committed document is the authority in both cases. `overridden`
    /// carries the committed count beside the local delta, so nothing can
    /// state the effective set without also stating the policy it departed
    /// from — a silent override is a worse defect than the shared artifact
    /// the override exists to end.
    public enum Origin: Equatable, Sendable {
        /// No local override is present; the committed document is in
        /// effect verbatim.
        case committed(count: Swift.Int)

        /// A local override is present and applied over the committed
        /// document.
        case overridden(
            committed: Swift.Int,
            added: [Institute.Repository.Key],
            removed: [Institute.Repository.Key]
        )
    }
}

extension Institute.Selection.Origin {
    /// The repositories the local override adds to the committed selection.
    public var added: [Institute.Repository.Key] {
        switch self {
        case .committed: []
        case .overridden(_, let added, _): added
        }
    }

    /// The repositories the local override withholds from the committed
    /// selection — the answer to "why is this package not in my workspace".
    public var removed: [Institute.Repository.Key] {
        switch self {
        case .committed: []
        case .overridden(_, _, let removed): removed
        }
    }

    /// How many repositories the selection in effect names.
    public var effective: Swift.Int {
        switch self {
        case .committed(let count):
            count
        case .overridden(let committed, let added, let removed):
            committed + added.count - removed.count
        }
    }
}

extension Institute.Selection.Origin: CustomStringConvertible {
    /// One line naming both documents and the counts, plus a second line
    /// naming every withheld identity when the override removes anything.
    ///
    /// Removals are listed in full and additions are not, because the two
    /// answer different questions and only one of them is asked under
    /// duress: a developer reading this is looking for a package that is
    /// not there.
    public var description: Swift.String {
        switch self {
        case .committed(let count):
            return "selection: \(Institute.Selection.filename) — \(count) selected;"
                + " no local override"
        case .overridden(let committed, let added, let removed):
            let line =
                "selection: \(Institute.Selection.filename) — \(committed) selected;"
                + " \(Institute.Selection.Override.filename) — \(added.count) added,"
                + " \(removed.count) removed; \(effective) in effect"
            guard !removed.isEmpty else { return line }
            return line + "\n  \(Institute.Selection.Override.filename) withholds: "
                + removed.map(\.identity).joined(separator: ", ")
        }
    }
}
