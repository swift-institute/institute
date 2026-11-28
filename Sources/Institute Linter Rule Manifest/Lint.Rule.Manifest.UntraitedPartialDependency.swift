public import Lint
internal import Package
internal import SwiftSyntax

extension Lint.Rule {
    /// I7: in a package with a primary target, a target outside the primary target's closure takes a product from a
    /// package the closure does not reach only under a trait condition, one trait per such target, named for the
    /// peer when the target is glue to one package. A macro's declarations, its macro target and its implementation
    /// share one trait. While swift-institute/Issues#123 is open, a target whose source is gated by that trait meets
    /// the rule with an unconditional product dependency. Not judged here: that a trait of a target that is glue to
    /// several packages, or to none, is named for the target's role.
    public static let `untraited partial dependency` = Lint.Rule(
        id: "untraited partial dependency",
        default: .warning,
        controls: [
            .init(
                id: "untraited partial dependency one of two products",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Glob\", targets: [\"Owner Glob\"])], targets: ["
                    + ".target(name: \"Owner\"), "
                    + ".target(name: \"Owner Glob\", dependencies: [.target(name: \"Owner\"), "
                    + ".product(name: \"Glob\", package: \"swift-glob\")])])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "untraited partial dependency trait gated",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Glob\", targets: [\"Owner Glob\"])], traits: ["
                    + ".trait(name: \"Glob\")], targets: ["
                    + ".target(name: \"Owner\"), "
                    + ".target(name: \"Owner Glob\", dependencies: [.target(name: \"Owner\"), "
                    + ".product(name: \"Glob\", package: \"swift-glob\", "
                    + "condition: .when(traits: [\"Glob\"]))])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "untraited partial dependency shared core",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Glob\", targets: [\"Owner Glob\"])], targets: ["
                    + ".target(name: \"Owner Core\", dependencies: [.product(name: \"Span\", package: \"swift-span\")]), "
                    + ".target(name: \"Owner\", dependencies: [.target(name: \"Owner Core\")]), "
                    + ".target(name: \"Owner Glob\", dependencies: [.target(name: \"Owner Core\")])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "untraited partial dependency test support reaching only the primary target",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Test Support\", targets: [\"Owner Test Support\"])], targets: ["
                    + ".target(name: \"Owner\", dependencies: [.product(name: \"Span\", package: \"swift-span\")]), "
                    + ".target(name: \"Owner Test Support\", dependencies: [.target(name: \"Owner\")])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "untraited partial dependency test support is judged",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Test Support\", targets: [\"Owner Test Support\"])], targets: ["
                    + ".target(name: \"Owner\"), "
                    + ".target(name: \"Owner Test Support\", dependencies: [.target(name: \"Owner\"), "
                    + ".product(name: \"Testing Support\", package: \"swift-testing-support\")])])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "untraited partial dependency primary target needs it",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner\", targets: [\"Owner\"]), "
                    + ".library(name: \"Owner Core\", targets: [\"Owner Core\"])], targets: ["
                    + ".target(name: \"Owner Core\"), "
                    + ".target(name: \"Owner\", dependencies: [.target(name: \"Owner Core\"), "
                    + ".product(name: \"Span\", package: \"swift-span\")])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "untraited partial dependency no primary target",
                source: "let package = Package(name: \"swift-owner\", products: ["
                    + ".library(name: \"Owner Kernel\", targets: [\"Owner Kernel\"]), "
                    + ".library(name: \"Owner Glob\", targets: [\"Owner Glob\"])], targets: ["
                    + ".target(name: \"Owner Kernel\"), "
                    + ".target(name: \"Owner Glob\", dependencies: ["
                    + ".product(name: \"Glob\", package: \"swift-glob\")])])",
                path: "Package.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
            .init(
                id: "untraited partial dependency outside manifest",
                source: "let dependency = Target.Dependency.product(name: \"Glob\", package: \"swift-glob\")",
                path: "Sources/Fixture/Fixture.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            guard manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description) else {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            let graph = ManifestGraph(tree: source.tree)
            let coverage: Lint.Rule.Coverage =
                graph.unhandledSourceShape.map { .unmeasured(.unsupportedSourceShape($0)) } ?? .measured
            guard graph.primaryTarget != nil else {
                return Lint.Rule.Observation(findings: [], coverage: coverage, applicability: .inapplicable)
            }
            let sources = ManifestPackageSources.of(source)
            let findings = manifestUntraitedPartialDependencyFindings(graph, gate: { target in
                manifestTargetSourceGate(target, in: sources)
            }).map { finding in
                let location = source.converter.location(for: finding.position)
                return Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "untraited partial dependency",
                    message: finding.message
                )
            }
            return Lint.Rule.Observation(findings: findings, coverage: coverage)
        }
    )
}

internal let manifestUntraitedPartialDependencyStatement: Swift::String =
    "[untraited partial dependency] [I7]: in a package with a primary target, a target outside the primary "
    + "target's closure takes a product from a package the closure does not reach only under a trait condition, "
    + "one trait per such target, named for the peer when the target is glue to one package."

/// The identifiers that gate every file of `target` that has content, or nil when a file is not gated, the target
/// has no file with content, or the package is not on disk.
internal func manifestTargetSourceGate(
    _ target: Swift::String,
    in sources: ManifestPackageSources?
) -> Swift::Set<Swift::String>? {
    guard let sources, let files = sources.files[target] else { return nil }
    var gates: Swift::Set<Swift::String>?
    for file in files {
        switch sources.facts[file]?.gate {
        case .gated(let identifiers)?: gates = (gates ?? identifiers).intersection(identifiers)
        case .none?: continue
        case .open?, nil: return nil
        }
    }
    return gates
}

/// The findings of `untraited partial dependency` in `graph`, which has a primary target. `gate` gives the
/// identifiers that gate a target's whole source.
internal func manifestUntraitedPartialDependencyFindings(
    _ graph: ManifestGraph,
    gate: (Swift::String) -> Swift::Set<Swift::String>?
) -> [(position: AbsolutePosition, message: Swift::String)] {
    guard let primary = graph.primaryTarget else { return [] }
    let closure = graph.closure(of: primary.name)
    let reached = graph.packages(reachedBy: closure)
    let declaredTraits = Swift::Set(graph.traits)
    var findings: [(position: AbsolutePosition, message: Swift::String)] = []
    var traitUsers: [Swift::String: [Swift::String]] = [:]
    for target in graph.targets where target.kind == .regular || target.kind == .macro {
        guard !closure.contains(target.name) else { continue }
        var foreign: [(package: Swift::String, product: Swift::String, edge: ManifestGraph.Edge)] = []
        for edge in target.edges {
            guard case .product(let product, let package) = edge.reference, !reached.contains(package) else { continue }
            foreign.append((package, product, edge))
        }
        guard !foreign.isEmpty else { continue }
        let sourceGate = gate(target.name)?.intersection(declaredTraits) ?? []
        var reported: Swift::Set<Swift::String> = []
        for use in foreign where !use.edge.gated && sourceGate.isEmpty && reported.insert(use.package).inserted {
            findings.append(
                (
                    use.edge.position,
                    manifestUntraitedPartialDependencyStatement
                        + " `\(target.name)` takes `\(use.package)` without one, and `\(primary.name)` and the targets "
                        + "it reaches do not take `\(use.package)`; gate it with `condition: .when(traits: [...])`, or, "
                        + "while swift-institute/Issues#123 is open, gate the target's source with `#if` that trait. "
                        + "SwiftPM ignores the product filter (`ENABLE_TARGET_BASED_DEPENDENCY_RESOLUTION` is compiled "
                        + "out in `Manifest.dependenciesRequired`), so every consumer of any product of this package "
                        + "resolves and loads the dependency; only a trait condition that is switched off keeps it out "
                        + "of the graph."
                )
            )
        }
        let traits = Swift::Set(foreign.flatMap { $0.edge.traits }).union(sourceGate).sorted()
        if traits.count > 1 {
            findings.append(
                (
                    target.position,
                    manifestUntraitedPartialDependencyStatement
                        + " `\(target.name)` is gated by " + traits.map { "`\($0)`" }.joined(separator: ", ")
                        + "; one trait gates one target."
                )
            )
        }
        let peers = Swift::Set(foreign.map { $0.package })
        if traits.count == 1, let trait = traits.first, peers.count == 1, let peer = peers.first {
            let named =
                Package.Concept(type: [trait]) == Package.Concept(Package.Name(_unchecked: peer))
                || foreign.contains { Package.Concept(type: [$0.product]) == Package.Concept(type: [trait]) }
            if !named {
                findings.append(
                    (
                        target.position,
                        manifestUntraitedPartialDependencyStatement
                            + " `\(target.name)` is glue to `\(peer)` alone, so its trait is named for `\(peer)`, "
                            + "not `\(trait)`."
                    )
                )
            }
        }
        for trait in traits {
            if let other = traitUsers[trait]?.first(where: { !graph.macroGroup(of: target.name).contains($0) }) {
                findings.append(
                    (
                        target.position,
                        manifestUntraitedPartialDependencyStatement
                            + " `\(target.name)` and `\(other)` share the trait `\(trait)`; one trait gates one target, "
                            + "and only a macro's declarations, its macro target and its implementation share one."
                    )
                )
            }
            traitUsers[trait, default: []].append(target.name)
        }
    }
    return findings
}
