internal import Lint
internal import Package
internal import SwiftSyntax

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
