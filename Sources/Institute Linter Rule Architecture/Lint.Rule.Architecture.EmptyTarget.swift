internal import Institute_Linter_Rule_Manifest
public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    /// A regular target that declares nothing is no target: its sources hold only imports, or imports and namespace
    /// enums with no cases and no members. Macro declarations count as declarations, and `… Test Support` targets are
    /// judged. The finding is on the first file of the target.
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
                let relative = source.relativePath
                guard let owner = sources.target(containing: relative), owner.kind == .regular else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
                }
                let files = sources.files[owner.name] ?? []
                guard files.first == relative else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured)
                }
                empty = files.allSatisfy { sources.facts[$0]?.empty ?? false }
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
                    + "imports, or imports and namespace enums with no cases and no members. `\(target)` declares "
                    + "nothing; move what it imports to the targets that use it and remove it."
            )
            return Lint.Rule.Observation(findings: [finding], coverage: .measured)
        }
    )
}
