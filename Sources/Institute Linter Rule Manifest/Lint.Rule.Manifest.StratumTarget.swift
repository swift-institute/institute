public import Lint
internal import Package
internal import SwiftSyntax

extension Lint.Rule {
    /// A regular target named `<X> Primitive`, `<X> Core`, `<X> Shared`, `<X> Protocol` or `<X> Namespace` is a stratum
    /// when `<X>` claims the concept of the package, of another of its targets, or of a public type or typealias the
    /// package declares. A stratum is a position in a stack, not a role, and is never a target: it folds into the
    /// target it is a stratum of, also when a product exposes it. A macro's implementation target folds into its
    /// macro target.
    public static let `stratum target` = Lint.Rule(
        id: "stratum target",
        default: .warning,
        controls: [
            .init(
                id: "stratum target core of the primary target",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Core\", targets: [\"Owner Core\"])], targets: ["
                    + ".target(name: \"Owner Core\"), .target(name: \"Owner\", dependencies: [\"Owner Core\"])])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "stratum target a part's own name",
                source: "let package = Package(name: \"swift-sigma\", products: ["
                    + ".library(name: \"Sigma\", targets: [\"Sigma\"]), "
                    + ".library(name: \"Sigma Dublin Core\", targets: [\"Sigma Dublin Core\"])], targets: ["
                    + ".target(name: \"Sigma\"), .target(name: \"Sigma Dublin Core\", dependencies: [\"Sigma\"])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "stratum target macro implementation",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"])], targets: ["
                    + ".target(name: \"Owner\", dependencies: [\"Owner Macro\"]), "
                    + ".macro(name: \"Owner Macro\", dependencies: [\"Owner Macro Core\"]), "
                    + ".target(name: \"Owner Macro Core\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "stratum target outside manifest",
                source: "let target = Target.target(name: \"Owner Core\")",
                path: "Sources/Fixture/Fixture.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            guard manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description)
            else {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            let graph = ManifestGraph(tree: source.tree)
            let coverage: Lint.Rule.Coverage =
                graph.unhandledSourceShape.map { .unmeasured(.unsupportedSourceShape($0)) } ?? .measured
            var types: [Package.Concept: [Swift::String]] = [:]
            if let sources = ManifestPackageSources.of(source) {
                for (path, facts) in sources.facts {
                    for declaration in facts.declarations where declaration.isPublic && declaration.kind != .macro {
                        let owner = sources.target(containing: path)?.name ?? ""
                        types[Package.Concept(type: declaration.path), default: []].append(owner)
                    }
                }
            }
            let findings = manifestStratumTargetFindings(graph, types: types).map { finding in
                let location = source.converter.location(for: finding.position)
                return Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "stratum target",
                    message: finding.message
                )
            }
            return Lint.Rule.Observation(findings: findings, coverage: coverage)
        }
    )
}

internal let manifestStratumWords: [Swift::String] = ["Primitive", "Core", "Shared", "Protocol", "Namespace"]

/// The findings of `stratum target` in `graph`. `types` gives, for the concept of each public type or typealias the
/// package declares, the targets that declare it.
internal func manifestStratumTargetFindings(
    _ graph: ManifestGraph,
    types: [Package.Concept: [Swift::String]]
) -> [(position: AbsolutePosition, message: Swift::String)] {
    let statement =
        "[stratum target]: a target named `<X> Primitive`, `<X> Core`, `<X> Shared`, `<X> Protocol` or `<X> Namespace`, "
        + "where `<X>` claims the package, another of its targets or a public type it declares, is a stratum, and a "
        + "stratum is never a target."
    var findings: [(position: AbsolutePosition, message: Swift::String)] = []
    for target in graph.targets where target.kind == .regular {
        guard let word = manifestStratumWords.first(where: { target.name.hasSuffix(" " + $0) }) else { continue }
        let stem = Swift::String(target.name.dropLast(word.count + 1))
        let concept = Package.Concept(type: [stem])
        guard !stem.isEmpty else { continue }
        let peer = graph.targets.first { $0.name != target.name && Package.Concept(type: [$0.name]) == concept }
        let isPackage = graph.concept == concept
        let declaring = types[concept]?.first { $0 != target.name } ?? types[concept]?.first
        guard peer != nil || isPackage || declaring != nil else { continue }
        let into: Swift::String =
            if let peer { "`\(peer.name)`" } else if isPackage, let primary = graph.primaryTarget {
                "`\(primary.name)`"
            } else if let declaring, !declaring.isEmpty, declaring != target.name {
                "`\(declaring)`, which declares `\(stem)`"
            } else {
                "the target that holds `\(stem)`"
            }
        let macros = graph.macros(implementedBy: target.name)
        let action: Swift::String =
            if let macro = macros.first {
                " `\(target.name)` is the implementation of the macro target `\(macro)`; fold it into `\(macro)`, "
                    + "not into the target that declares the macros."
            } else {
                " `\(target.name)` is the `\(word)` stratum of `\(stem)`; fold it into \(into), also when a product "
                    + "exposes it."
            }
        findings.append((target.position, statement + action))
    }
    return findings
}
