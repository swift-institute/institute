internal import Institute_Linter_Rule_Manifest
public import Institute_Model
public import Lint
internal import Package
internal import SwiftSyntax

extension Lint.Rule {
    /// A regular target that declares nothing is no target: its sources hold only imports, or imports and namespace
    /// enums with no cases and no members. A target that declares only the namespace its own package's name claims
    /// (`IETF` in swift-ietf) is no finding. Macro declarations count as declarations, and `… Test Support` targets
    /// are judged. The finding is on the first file of the target.
    public static let `empty target` = Lint.Rule(
        id: "empty target",
        default: .warning,
        controls: [
            .init(
                id: "empty target re-exports only",
                source: "@_exported public import Owner\n@_exported public import Glob",
                path: "Sources/Owner Glob/exports.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "empty target namespace enum only",
                source: "public import Owner\n\npublic enum Glob {}",
                path: "Sources/Owner Glob/Glob.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "empty target declares a type",
                source: "public import Owner\n\nextension Owner {\n    public struct Glob {}\n}",
                path: "Sources/Owner Glob/Owner.Glob.swift",
                expectation: .clean
            ),
            .init(
                id: "empty target declares a macro",
                source: "@freestanding(expression)\npublic macro stringify<T>(_ value: T) -> (T, String) = "
                    + "#externalMacro(module: \"Owner Macro Plugin\", type: \"Stringify\")",
                path: "Sources/Owner Macro/Owner.Macro.swift",
                expectation: .clean
            ),
            .init(
                id: "empty target test",
                source: "@_exported public import Owner",
                path: "Tests/Owner Tests/exports.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            let empty: Swift::Bool
            let target: Swift::String
            if let sources = ManifestPackageSources.of(source) {
                let relative = ManifestPackageSources.relative(source)
                guard let owner = sources.target(containing: relative), owner.kind == .regular else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
                }
                let files = sources.files[owner.name] ?? []
                guard files.first == relative else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured)
                }
                let declarations = files.flatMap { sources.facts[$0]?.declarations ?? [] }
                let namespace =
                    !declarations.isEmpty
                    && declarations.allSatisfy { Package.Concept(type: $0.path) == sources.graph.concept }
                empty = !namespace && files.allSatisfy { sources.facts[$0]?.empty ?? false }
                target = owner.name
            } else {
                guard let owner = manifestSourceTarget(ofPath: source.file.filePath),
                    !source.file.filePath.split(separator: "/").contains("Tests")
                else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
                }
                empty = ManifestSourceFacts(tree: source.tree).empty
                target = owner
            }
            guard empty else { return Lint.Rule.Observation(findings: [], coverage: .measured) }
            let location = source.converter.location(for: AbsolutePosition(utf8Offset: 0))
            let finding = Diagnostic.Record(
                location: Source.Location(
                    fileID: source.file.fileID,
                    filePath: source.file.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "empty target",
                message: "[empty target]: a regular target that declares nothing is no target: its sources hold only "
                    + "imports, or imports and namespace enums with no cases and no members, other than the namespace "
                    + "its own package's name claims. `\(target)` declares "
                    + "nothing; move what it imports to the targets that use it and remove it."
            )
            return Lint.Rule.Observation(findings: [finding], coverage: .measured)
        }
    )
}

extension Lint.Rule {
    /// One package declares a public type path once. A declaration inside a constrained extension has its path
    /// together with the extension's requirements, so two `Error` types in two differently constrained extensions of
    /// one generic type are two paths. Declarations under different `#if` conditions are two paths too, since at most
    /// one of them may be compiled. Macros overload as functions do and are not judged, and neither are macro and
    /// executable targets, which are modules of their own. The finding is on the later declaration, in the order of
    /// the files' paths.
    public static let `duplicate type path` = Lint.Rule(
        id: "duplicate type path",
        default: .warning,
        controls: [
            .init(
                id: "duplicate type path twice in one file",
                source: "extension Owner {\n    public struct Error: Swift.Error {}\n}\n"
                    + "extension Owner {\n    public enum Error: Swift.Error {}\n}",
                path: "Sources/Owner/Owner.Error.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "duplicate type path differently constrained extensions",
                source: "extension Box where Element: Equatable {\n    public struct Error: Swift.Error {}\n}\n"
                    + "extension Box where Element: Hashable {\n    public struct Error: Swift.Error {}\n}",
                path: "Sources/Owner/Box.Error.swift",
                expectation: .clean
            ),
            .init(
                id: "duplicate type path alternate conditional branches",
                source: "#if os(macOS)\npublic struct Owner {}\n#else\npublic struct Owner {}\n#endif",
                path: "Sources/Owner/Owner.swift",
                expectation: .clean
            ),
            .init(
                id: "duplicate type path internal",
                source: "extension Owner {\n    struct Cache {}\n}\nextension Owner {\n    struct Cache {}\n}",
                path: "Sources/Owner/Owner.Cache.swift",
                expectation: .clean
            ),
            .init(
                id: "duplicate type path overloaded macro",
                source: "@freestanding(expression)\npublic macro column(_ name: String) -> Int = "
                    + "#externalMacro(module: \"M\", type: \"C\")\n@freestanding(expression)\n"
                    + "public macro column(_ index: Int) -> Int = #externalMacro(module: \"M\", type: \"C\")",
                path: "Sources/Owner/Macros.swift",
                expectation: .clean
            ),
            .init(
                id: "duplicate type path tests",
                source: "extension Owner {\n    public struct Fixture {}\n}\nextension Owner {\n    public struct Fixture {}\n}",
                path: "Tests/Owner Tests/Owner.Fixture.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            let relative = ManifestPackageSources.relative(source)
            var seen: Swift::Set<Swift::String> = []
            if let sources = ManifestPackageSources.of(source) {
                guard sources.target(containing: relative)?.kind == .regular else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
                }
                for file in sources.paths where file < relative && sources.target(containing: file)?.kind == .regular {
                    for declaration in sources.facts[file]?.declarations ?? []
                    where declaration.isPublic && declaration.kind != .macro {
                        seen.insert(declaration.key)
                    }
                }
            } else {
                guard manifestSourceTarget(ofPath: source.file.filePath) != nil,
                    !source.file.filePath.split(separator: "/").contains("Tests")
                else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
                }
            }
            var findings: [Diagnostic.Record] = []
            for declaration in ManifestSourceFacts(tree: source.tree).declarations
            where declaration.isPublic && declaration.kind != .macro {
                guard !seen.insert(declaration.key).inserted else { continue }
                let location = source.converter.location(for: declaration.position)
                let path = declaration.path.joined(separator: ".")
                findings.append(
                    Diagnostic.Record(
                        location: Source.Location(
                            fileID: source.file.fileID,
                            filePath: source.file.filePath,
                            line: location.line,
                            column: location.column
                        ),
                        severity: severity,
                        identifier: "duplicate type path",
                        message: "[duplicate type path]: one package declares a public type path once, a path in a "
                            + "constrained extension together with the extension's requirements. `\(path)` is declared "
                            + "again here; keep one declaration and remove or rename the other."
                    )
                )
            }
            return Lint.Rule.Observation(findings: findings, coverage: .measured)
        }
    )
}

extension Lint.Rule {
    /// The last sentence of `top level type owner`: a package owns at least one declaration (a type, a typealias or
    /// a macro) at the path its name claims, read whole from the first component: `swift-ietf-rfc-3986` claims
    /// `IETF.RFC.3986`, and `swift-iso-9945` claims `ISO.9945`. A package that declares public types and none at that
    /// path is found once, on the first public declaration of its first file. A composition that only extends a type
    /// another package declares is found too.
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
                    let relative = ManifestPackageSources.relative(source)
                    var first: Swift::String?
                    for file in sources.paths {
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
                        + "or a macro, at the path its name claims, read whole from the first component. "
                        + "`swift-ietf-rfc-3986` claims `IETF.RFC.3986`, and `\(repository.name)` declares public types "
                        + "and none at the path it claims; declare what its name claims, or rename the package for what "
                        + "it declares."
                )
                return Lint.Rule.Observation(findings: [finding], coverage: .measured)
            }
        )
    }
}
