internal import Institute_Linter_Rule_Manifest
public import Lint
internal import SwiftSyntax

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
            let relative = source.relativePath
            var seen: Swift::Set<Swift::String> = []
            if let sources = ManifestPackageSources.of(source) {
                guard sources.target(containing: relative)?.kind == .regular else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
                }
                for file in sources.allFiles where file < relative && sources.target(containing: file)?.kind == .regular {
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
