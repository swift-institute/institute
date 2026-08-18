public import File_System
public import Institute_Model
internal import SPM_Standard

extension Institute.Composition {
    /// The canonical composed-graph representation: every normalized
    /// package as a path dependency, the package-qualified library
    /// products the synthetic target depends on, explicit exclusion
    /// records with reason codes, and the population evidence the
    /// coherence receipt consumes.
    ///
    /// Rendering accepts only a validated plan. A library-less package
    /// stays visible as a path dependency and in population evidence;
    /// it is excluded from synthetic target dependencies only, with a
    /// reason code — never silently dropped from the graph, where
    /// transitive resolution could silently choose a remote source for
    /// it.
    public struct BuildPlan: Swift.Equatable, Swift.Sendable {
        /// The explicit seeds this plan was normalized from; the full
        /// roster when the scope was the inventory.
        public let seeds: [Swift.String]

        /// Every package in the normalized closure, ordered by
        /// reference — deterministic run over run for one plan.
        public let packages: [Package]

        /// A plan with no library-product contribution can only build
        /// an empty synthetic target — a green nothing. Refused.
        public init(
            seeds: [Swift.String],
            packages: [Package]
        ) throws(Institute.Composition.BuildPlan.Error) {
            let ordered = packages.sorted { $0.reference < $1.reference }
            guard ordered.contains(where: { $0.exclusion == nil }) else {
                throw .noLibraryContribution
            }
            self.seeds = seeds.sorted()
            self.packages = ordered
        }
    }
}

extension Institute.Composition.BuildPlan {
    /// One path-dependency entry of the composed graph.
    public struct Package: Swift.Equatable, Swift.Sendable {
        /// The identity SwiftPM resolves for this path dependency —
        /// derived from the materialized directory, admitted only
        /// after evaluation. Product dependencies are qualified with
        /// this value.
        public let identity: Swift.String

        /// The path rendered into `.package(path:)`, expressed
        /// relative to the generated root — traversal into another
        /// registered root included.
        public let reference: Swift.String

        /// Library products the synthetic target depends on. Empty
        /// exactly when ``exclusion`` is non-nil.
        public let libraryProducts: [Swift.String]

        /// Regular and executable targets, the shared population
        /// filter.
        public let buildableTargetCount: Swift.Int

        /// Why this package contributes no synthetic target
        /// dependency; `nil` for a contributing package.
        public let exclusion: Exclusion?

        public init(
            identity: Swift.String,
            reference: Swift.String,
            libraryProducts: [Swift.String],
            buildableTargetCount: Swift.Int
        ) {
            self.identity = identity
            self.reference = reference
            self.libraryProducts = libraryProducts
            self.buildableTargetCount = buildableTargetCount
            self.exclusion = libraryProducts.isEmpty ? .noLibraryProduct : nil
        }
    }

    /// The typed reason a package is excluded from synthetic target
    /// dependencies.
    public enum Exclusion: Swift.String, Swift.Equatable, Swift.Sendable {
        /// Only a library product can be named in another target's
        /// dependencies; a package exposing none has no way into the
        /// composed graph through product-dependency composition.
        case noLibraryProduct = "no-library-product"
    }

    public enum Error: Swift.Error, Swift.CustomStringConvertible {
        /// No package contributes a library product; building the plan
        /// would produce a green empty target, never a measurement.
        case noLibraryContribution

        public var description: Swift.String {
            switch self {
            case .noLibraryContribution:
                "no package in the plan contributes a library product"
            }
        }
    }
}

extension Institute.Composition.BuildPlan {
    /// The path-dependency population — every package, contributing or
    /// excluded.
    public var pathDependencyCount: Swift.Int { packages.count }

    /// Packages contributing at least one library product.
    public var libraryContributingCount: Swift.Int {
        packages.count { $0.exclusion == nil }
    }

    /// The exclusion records, in plan order.
    public var exclusions: [(identity: Swift.String, reason: Exclusion)] {
        packages.compactMap { package in
            package.exclusion.map { (package.identity, $0) }
        }
    }

    /// The whole composed reachable population: the buildable-target
    /// count of every contributing package — the same formula the
    /// manifest-based instrument has always used, computed from this
    /// exact plan.
    public var expectedTargetCount: Swift.Int {
        packages.filter { $0.exclusion == nil }.reduce(0) { $0 + $1.buildableTargetCount }
    }
}

extension Institute.Composition.BuildPlan {
    /// Builds the plan for `entries` in `workspace`, expressing every
    /// path reference relative to the workspace's generated root.
    public init(
        entries: [Institute.Composition.SourceMap.Entry],
        seeds: [Swift.String],
        workspace: Institute.Composition.Workspace
    ) throws(Institute.Composition.BuildPlan.Error) {
        let root = Institute.Composed.Root.directory(in: workspace).path
        try self.init(
            seeds: seeds,
            packages: entries.map { entry in
                let libraries: [Swift.String] = entry.evaluation.products.compactMap { product in
                    guard case .library = product.kind else { return nil }
                    return product.name.underlying
                }
                var buildable = 0
                for target in entry.evaluation.targets {
                    switch target.kind {
                    case .regular, .executable: buildable += 1
                    case .test, .plugin, .binary, .system, .macro: continue
                    }
                }
                return .init(
                    identity: entry.identity,
                    reference: Self.relative(from: root, to: entry.directory.path),
                    libraryProducts: libraries,
                    buildableTargetCount: buildable
                )
            }
        )
    }

    /// `target` expressed relative to `base` by component walk —
    /// shared prefix dropped, one `..` per remaining base component.
    /// Deterministic, and representable across registered roots.
    static func relative(from base: File.Path, to target: File.Path) -> Swift.String {
        let baseComponents = base.components.map(\.string)
        let targetComponents = target.components.map(\.string)
        var shared = 0
        while shared < baseComponents.count,
            shared < targetComponents.count,
            baseComponents[shared] == targetComponents[shared]
        {
            shared += 1
        }
        let ups = Swift.Array(
            repeating: "..",
            count: baseComponents.count - shared
        )
        let segments = ups + targetComponents[shared...]
        return segments.isEmpty ? "." : segments.joined(separator: "/")
    }
}
