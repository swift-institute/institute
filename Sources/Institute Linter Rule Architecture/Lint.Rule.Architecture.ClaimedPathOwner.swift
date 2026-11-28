internal import Institute_Linter_Rule_Manifest
internal import Institute_Model
internal import Lint
internal import Package
internal import SwiftSyntax

/// The concepts `repository`'s name claims: its own, and in the standards layer, for `swift-x-standard`, `X`'s.
internal func architectureClaimedConcepts(_ repository: Institute.Repository.Coordinate) -> Swift::Set<Swift::String> {
    let concept = Package.Concept(Package.Name(_unchecked: repository.name)).text
    var concepts: Swift::Set<Swift::String> = [concept]
    if repository.organization.layer == .standards, concept.hasSuffix("standard"), concept.count > "standard".count {
        concepts.insert(Swift::String(concept.dropLast("standard".count)))
    }
    return concepts
}

/// Whether `declaration` is at the path `repository`'s name claims. In the standards layer a path may sit under an
/// authority's namespace, so any trailing part of it may claim the name.
internal func architectureClaims(
    _ declaration: ManifestSourceFacts.Declaration,
    repository: Institute.Repository.Coordinate
) -> Swift::Bool {
    let concepts = architectureClaimedConcepts(repository)
    let starts = repository.organization.layer == .standards ? Swift::Array(declaration.path.indices) : [0]
    return starts.contains { concepts.contains(Package.Concept(type: declaration.path[$0...]).text) }
}

internal func architectureClaimedPathOwnerControls(
    in repository: Institute.Repository.Coordinate?
) -> [Lint.Rule.Control] {
    let name = repository?.name ?? "swift-package"
    let root = "/workspace/\(name)"
    let words = architecturePackageWords(of: Package.Name(_unchecked: name))
    let owner = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    let target = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    guard let repository, repository.organization.layer != .control else {
        return [
            .init(
                id: "claimed path owner outside the layers",
                source: "public enum Zebra {}",
                path: "\(root)/Sources/\(target)/Zebra.swift",
                expectation: .clean,
                applicability: .inapplicable
            )
        ]
    }
    let zebra = architectureClaimedConcepts(repository).contains("zebra")
    return [
        .init(
            id: "claimed path owner none at the claimed path",
            source: "public enum Zebra {}",
            path: "\(root)/Sources/\(target)/Zebra.swift",
            expectation: zebra ? .clean : .findings(1)
        ),
        .init(
            id: "claimed path owner owns its path",
            source: "public enum \(owner) {}\npublic enum Zebra {}",
            path: "\(root)/Sources/\(target)/\(owner).swift",
            expectation: .clean
        ),
        .init(
            id: "claimed path owner no public declaration",
            source: "enum Zebra {}",
            path: "\(root)/Sources/\(target)/Zebra.swift",
            expectation: .clean
        ),
        .init(
            id: "claimed path owner tests",
            source: "public enum Zebra {}",
            path: "\(root)/Tests/\(target) Tests/Zebra.swift",
            expectation: .clean,
            applicability: .inapplicable
        ),
    ]
}
