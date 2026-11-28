internal import Lint
internal import Package
internal import SwiftSyntax

/// Whether `source` is the manifest at the root of the linted package, not one nested in a folder of it.
internal func manifestIsRootManifest(_ source: borrowing Lint.Source.Parsed) -> Swift::Bool {
    !ManifestPackageSources.relative(source).contains("/")
}

internal func manifestNoPrimaryTargetMessage(_ graph: ManifestGraph, package: Swift::String) -> Swift::String? {
    let statement =
        "[no primary target] [I4]: a library's root package has a regular target whose name claims the concept the "
        + "package's name claims, and a library product of that name."
    guard let primary = graph.primaryTarget else {
        let products = graph.products.map { "`\($0.name)`" }.joined(separator: ", ")
        return statement + " `\(package)` has no regular target named for it; its products are \(products). "
            + "Name the target that holds what the package's name claims for the package, and give it the product."
    }
    if let product = graph.primaryProduct, product.targets.contains(primary.name) { return nil }
    if let product = graph.primaryProduct {
        return statement + " The product `\(product.name)` does not hold the target `\(primary.name)`."
    }
    return statement + " No library product exposes `\(primary.name)`; add `.library(name: \"\(primary.name)\", "
        + "targets: [\"\(primary.name)\"])`."
}
