internal import Institute_Linter_Rule_Manifest
internal import Institute_Model
internal import Lint
internal import Package
internal import SwiftSyntax

/// Whether `declaration` is at the path `repository`'s name claims, read whole from its first component:
/// `swift-ietf-rfc-3986` claims `IETF.RFC.3986`, and `swift-iso-9945` claims `ISO.9945`.
internal func architectureClaims(
    _ declaration: ManifestSourceFacts.Declaration,
    repository: Institute.Repository.Coordinate
) -> Swift::Bool {
    Package.Concept(type: declaration.path) == Package.Concept(Package.Name(_unchecked: repository.name))
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
    let zebra = Package.Concept(Package.Name(_unchecked: repository.name)).text == "zebra"
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
