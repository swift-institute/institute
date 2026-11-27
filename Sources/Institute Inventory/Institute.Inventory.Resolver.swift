public import Institute_Model

extension Institute.Inventory {
    /// Resolves written type chains against declared types, as Swift's
    /// lexical lookup does, by syntax and the target graph alone.
    ///
    /// The candidates are the declarations of the targets a referencing
    /// target can see. The chain is tried relative to each enclosing scope,
    /// innermost first; the first scope in which its first component names a
    /// visible type, or a visible namespace (the extended type of an
    /// extension that declares types, such as `Swift.String`), wins, and the
    /// chain is then extended to its longest declared prefix. A typealias is
    /// recorded, not followed. A `Module::` selector is dropped, and so is a
    /// plain leading module name that names no visible type. Declared paths
    /// that begin with such a module name are also known without it, so
    /// `Swift.String.Coder`, `Swift::String.Coder` and `String.Coder` meet.
    public struct Resolver: Sendable {
        let index: [Swift.String: [Candidate]]
        let prefixes: [Swift.String: Swift.Set<Swift.Int>]
        let modules: Swift.Set<Swift.String>

        /// - Parameters:
        ///   - declarations: each declared path with its declaring target.
        ///   - modules: the module names known: every target's module name,
        ///     every imported module, `Swift`.
        public init(declarations: [(path: [Swift.String], target: Swift.Int)], modules: Swift.Set<Swift.String>) {
            let topLevel = Swift.Set(declarations.filter { $0.path.count == 1 }.map { $0.path[0] })
            let strippable = modules.subtracting(topLevel)
            var index: [Swift.String: [Candidate]] = [:]
            var prefixes: [Swift.String: Swift.Set<Swift.Int>] = [:]
            for declaration in declarations where !declaration.path.isEmpty {
                let candidate = Candidate(path: declaration.path.joined(separator: "."), target: declaration.target)
                var keys = [declaration.path]
                if declaration.path.count > 1, strippable.contains(declaration.path[0]) {
                    keys.append(Swift.Array(declaration.path.dropFirst()))
                }
                for key in keys {
                    let joined = key.joined(separator: ".")
                    if !(index[joined]?.contains(candidate) ?? false) { index[joined, default: []].append(candidate) }
                    var prefix = ""
                    for component in key {
                        prefix = prefix.isEmpty ? component : prefix + "." + component
                        prefixes[prefix, default: []].insert(declaration.target)
                    }
                }
            }
            self.index = index
            self.prefixes = prefixes
            self.modules = strippable
        }
    }
}

extension Institute.Inventory.Resolver {
    /// Resolves `chain`, written inside `from`, for a target that sees `visible`.
    public func resolve(
        chain written: [Swift.String],
        module: Swift.String = "",
        from: [Swift.String],
        generic: Swift.Bool = false,
        visible: Swift.Set<Swift.Int>
    ) -> Institute.Inventory.Resolution {
        guard !generic, let first = written.first else { return .init(candidates: []) }
        var chain = written
        if first == "Self" {
            guard !from.isEmpty else { return .init(candidates: []) }
            chain = from + chain.dropFirst()
        }
        if let found = lookup(chain, from: from, visible: visible) { return .init(candidates: found) }
        if chain.count > 1, modules.contains(chain[0]) {
            if let found = lookup(Swift.Array(chain.dropFirst()), from: from, visible: visible) {
                return .init(candidates: found)
            }
        }
        return .init(candidates: [])
    }

    func lookup(
        _ chain: [Swift.String],
        from: [Swift.String],
        visible: Swift.Set<Swift.Int>
    ) -> [Institute.Inventory.Candidate]? {
        var scope = from
        while true {
            let head = (scope + [chain[0]]).joined(separator: ".")
            if let declaring = prefixes[head], Self.intersects(declaring, visible) {
                for length in Swift.stride(from: chain.count, through: 1, by: -1) {
                    let key = (scope + chain.prefix(length)).joined(separator: ".")
                    let found = (index[key] ?? []).filter { visible.contains($0.target) }
                    if !found.isEmpty { return Self.perTarget(found) }
                }
                return nil
            }
            guard !scope.isEmpty else { return nil }
            scope.removeLast()
        }
    }

    static func intersects(_ lhs: Swift.Set<Swift.Int>, _ rhs: Swift.Set<Swift.Int>) -> Swift.Bool {
        lhs.count < rhs.count ? lhs.contains(where: rhs.contains) : rhs.contains(where: lhs.contains)
    }

    /// One candidate per declaring target, the first declared path kept.
    static func perTarget(_ candidates: [Institute.Inventory.Candidate]) -> [Institute.Inventory.Candidate] {
        var seen = Swift.Set<Swift.Int>()
        return candidates.filter { seen.insert($0.target).inserted }.sorted { $0.target < $1.target }
    }
}
