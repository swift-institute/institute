public import File_System
public import Institute_Model
public import Package_Manager
public import SPM_Standard

extension Institute.Composition {
    /// Which checkout each composed repository resolves to: one default
    /// hierarchy plus exact inventory-reference → hierarchy overrides.
    ///
    /// Normalization is the one path from a scope and a map to a
    /// validated assignment. It resolves every repository through the
    /// hierarchy registry and ``Institute/Layout``, proves containment
    /// per repository against **its own** root, requires and evaluates
    /// each manifest, and refuses duplicate physical paths and duplicate
    /// evaluated identities — in a fixed order, so the same inputs fail
    /// the same way every time.
    public struct SourceMap: Swift.Equatable, Swift.Sendable {
        /// The hierarchy resolving every repository without an override.
        public let defaultHierarchy: Institute.Hierarchy.ID

        /// Exact inventory-reference → hierarchy assignments.
        public let overrides: [Swift.String: Institute.Hierarchy.ID]

        public init(
            defaultHierarchy: Institute.Hierarchy.ID,
            overrides: [Swift.String: Institute.Hierarchy.ID] = [:]
        ) {
            self.defaultHierarchy = defaultHierarchy
            self.overrides = overrides
        }
    }
}

extension Institute.Composition.SourceMap {
    /// One normalized assignment: a repository, the hierarchy it
    /// resolves through, its validated checkout directory, the identity
    /// SwiftPM will resolve for it as a path dependency, and its
    /// evaluated manifest.
    ///
    /// ``identity`` is derived from the materialized directory — the
    /// fact SwiftPM actually uses — and is admitted only after the
    /// manifest at that directory evaluates; an inventory name never
    /// becomes an identity without evaluation.
    public struct Entry: Swift.Equatable, Swift.Sendable {
        public let repository: Institute.Repository
        public let hierarchy: Institute.Hierarchy.ID
        public let directory: File.Directory
        public let identity: Swift.String
        public let evaluation: Package.Manifest.Evaluation

        public init(
            repository: Institute.Repository,
            hierarchy: Institute.Hierarchy.ID,
            directory: File.Directory,
            identity: Swift.String,
            evaluation: Package.Manifest.Evaluation
        ) {
            self.repository = repository
            self.hierarchy = hierarchy
            self.directory = directory
            self.identity = identity
            self.evaluation = evaluation
        }
    }
}

extension Institute.Composition.SourceMap {
    /// Normalizes `scope` under this map into deterministic
    /// inventory-reference order.
    ///
    /// `evaluate` is the package-graph authority —
    /// ``Package/Manager/evaluation(at:)`` by default, injectable so a
    /// fixture can exercise every law without spawning SwiftPM.
    /// Forward closure is computed only from evaluated manifests, by
    /// mapping each dependency's evaluated identity back to an
    /// inventory repository. An identity outside the roster is
    /// lawfully external — contributing nothing — only when its
    /// location is also outside every Institute-governed organization;
    /// a governed edge absent from the declared population fails
    /// closed as ``Error/populationIntegrity(reference:identity:organization:)``.
    public func normalized(
        scope: Institute.Composition.Scope,
        roster: [Institute.Repository],
        at checkout: File.Directory,
        evaluate: (Swift.String) throws(Package.Manager.Error) -> Package.Manifest.Evaluation = {
            directory throws(Package.Manager.Error) in
            try Package.Manager().evaluation(at: directory)
        }
    ) throws(Error) -> [Entry] {
        let byReference = Swift.Dictionary(
            roster.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let governed = Swift.Set(roster.map(\.organization))
            .union(roster.map(\.layer.organization))

        for reference in overrides.keys.sorted() {
            guard byReference[reference] != nil else {
                throw .unknownOverride(reference)
            }
        }

        let seeds: [Swift.String]
        switch scope {
        case .inventory:
            seeds = roster.map(\.name).sorted()

        case .seeds(let explicit):
            guard !explicit.isEmpty else { throw .emptySeeds }
            for seed in explicit.sorted() where byReference[seed] == nil {
                throw .unknownSeed(seed)
            }
            seeds = explicit.sorted()
        }

        var entries = [Swift.String: Entry]()
        var pending = seeds
        var visited = Swift.Set<Swift.String>()
        var roots = [Institute.Hierarchy.ID: File.Directory]()

        while let reference = pending.first {
            pending.removeFirst()
            guard visited.insert(reference).inserted else { continue }
            guard let repository = byReference[reference] else {
                throw .unassigned(reference)
            }

            let hierarchy = overrides[reference] ?? defaultHierarchy
            let root: File.Directory
            if let known = roots[hierarchy] {
                root = known
            } else {
                do throws(Institute.Hierarchy.Registry.Error) {
                    root = try Institute.Hierarchy.Registry.status(of: hierarchy, at: checkout)
                } catch {
                    throw .hierarchy("\(hierarchy)", .composition("\(error)"))
                }
                roots[hierarchy] = root
            }

            let directory: File.Directory
            do throws(Institute.Error) {
                directory = try Institute.Layout.directory(for: repository, at: root)
                try Institute.Root.preflight(directory, under: root)
            } catch {
                throw .placement(reference, error)
            }

            guard directory[file: "Package.swift"].stat.exists else {
                throw .missingManifest(reference)
            }

            let evaluation: Package.Manifest.Evaluation
            do throws(Package.Manager.Error) {
                evaluation = try evaluate(directory.description)
            } catch {
                throw .evaluation(reference, "\(error)")
            }

            let identity = reference.lowercased()
            let evaluatedName = evaluation.name.underlying.lowercased()
            guard evaluatedName == identity else {
                throw .identityDivergence(reference: reference, evaluated: evaluatedName)
            }

            entries[reference] = .init(
                repository: repository,
                hierarchy: hierarchy,
                directory: directory,
                identity: identity,
                evaluation: evaluation
            )

            for dependency in evaluation.dependencies {
                let token = dependency.identity.underlying
                if byReference[token] != nil {
                    if !visited.contains(token) {
                        pending.append(token)
                    }
                    continue
                }
                // A dependency outside the roster is lawfully external
                // only when it also lives outside every Institute-owned
                // organization. A governed-organization edge absent
                // from the declared population is a population-integrity
                // failure, never a silent remote resolution — the
                // swift-tls class (institute-application#212).
                if case .sourceControl(_, .remote(let location), _) = dependency.source {
                    let url = "\(location)"
                    if let organization = Self.organization(of: url),
                        governed.contains(organization)
                    {
                        throw .populationIntegrity(
                            reference: reference,
                            identity: token,
                            organization: organization
                        )
                    }
                }
            }
        }

        for reference in overrides.keys.sorted() where entries[reference] == nil {
            throw .outOfScopeOverride(reference)
        }

        var byPath = [Swift.String: Swift.String]()
        var byIdentity = [Swift.String: Swift.String]()
        let ordered = entries.values.sorted { $0.repository.name < $1.repository.name }
        for entry in ordered {
            let reference = entry.repository.name

            let physical: Swift.String
            do throws(File.System.Canonical.Error) {
                physical = try File.System.Canonical.resolve(entry.directory.path).description
            } catch {
                physical = entry.directory.path.description
            }
            if let first = byPath[physical] {
                throw .duplicatePath(first, reference)
            }
            byPath[physical] = reference

            if let first = byIdentity[entry.identity] {
                throw .duplicateIdentity(
                    identity: entry.identity,
                    first: first,
                    second: reference
                )
            }
            byIdentity[entry.identity] = reference
        }

        return ordered
    }
}

extension Institute.Composition.SourceMap {
    /// The GitHub organization of a source-control location, or `nil`
    /// when the location does not name one.
    static func organization(of url: Swift.String) -> Swift.String? {
        guard let range = url.range(of: "github.com/") else { return nil }
        let remainder = url[range.upperBound...]
        let segment = remainder.prefix { $0 != "/" }
        return segment.isEmpty ? nil : Swift.String(segment)
    }
}
