internal import Institute_Linter_Rule_Manifest
public import Institute_Model
public import Lint
internal import Package
internal import SwiftSyntax

extension Lint.Rule {
    /// The last sentence of `top level type owner`: a package owns at least one declaration (a type, a typealias or
    /// a macro) at the path its name claims. A package that declares public types and none at that path is found once,
    /// on the first public declaration of its first file. In the standards layer the path may sit under an authority's
    /// namespace (`IETF.RFC.3986` for `swift-rfc-3986`), and `swift-x-standard` claims `X`.
    public static let `claimed path owner` = Lint.Rule.`claimed path owner`(in: nil)

    public static func `claimed path owner`(in repository: Institute.Repository.Coordinate?) -> Lint.Rule {
        Lint.Rule(
            id: "claimed path owner",
            default: .warning,
            controls: architectureClaimedPathOwnerControls(in: repository),
            observe: { source, severity in
                guard let repository, repository.organization.layer != .control,
                    let target = manifestSourceTarget(ofPath: source.file.filePath),
                    !target.hasSuffix("Test Support")
                else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
                }
                let own = ManifestSourceFacts(tree: source.tree).declarations.filter(\.isPublic)
                var claimed = own.contains { architectureClaims($0, repository: repository) }
                if let sources = ManifestPackageSources.of(source) {
                    let relative = source.relativePath
                    var first: Swift::String?
                    for file in sources.allFiles {
                        guard sources.target(containing: file).map({ !$0.name.hasSuffix("Test Support") }) ?? false else { continue }
                        let declarations = (sources.facts[file]?.declarations ?? []).filter(\.isPublic)
                        if first == nil, !declarations.isEmpty { first = file }
                        if declarations.contains(where: { architectureClaims($0, repository: repository) }) { claimed = true }
                    }
                    guard first == relative else { return Lint.Rule.Observation(findings: [], coverage: .measured) }
                }
                guard !claimed, let declaration = own.first else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured)
                }
                let location = source.converter.location(for: declaration.position)
                let finding = Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "claimed path owner",
                    message: "[claimed path owner] [ARCH-ONE-TYPE]: a package owns at least one declaration, a type, a typealias "
                        + "or a macro, at the path its name claims. `\(repository.name)` declares public types and none "
                        + "at that path; declare what its name claims, or rename the package for what it declares."
                )
                return Lint.Rule.Observation(findings: [finding], coverage: .measured)
            }
        )
    }
}

/// The concepts `repository`'s name claims: its own, and in the standards layer, for `swift-x-standard`, `X`'s.
private func architectureClaimedConcepts(_ repository: Institute.Repository.Coordinate) -> Swift::Set<Swift::String> {
    let concept = Package.Concept(Package.Name(_unchecked: repository.name)).text
    var concepts: Swift::Set<Swift::String> = [concept]
    if repository.organization.layer == .standards, concept.hasSuffix("standard"), concept.count > "standard".count {
        concepts.insert(Swift::String(concept.dropLast("standard".count)))
    }
    return concepts
}

/// Whether `declaration` is at the path `repository`'s name claims. In the standards layer a path may sit under an
/// authority's namespace, so any trailing part of it may claim the name.
private func architectureClaims(
    _ declaration: ManifestSourceFacts.Declaration,
    repository: Institute.Repository.Coordinate
) -> Swift::Bool {
    let concepts = architectureClaimedConcepts(repository)
    let starts = repository.organization.layer == .standards ? Swift::Array(declaration.path.indices) : [0]
    return starts.contains { concepts.contains(Package.Concept(type: declaration.path[$0...]).text) }
}

private func architectureClaimedPathOwnerControls(
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
