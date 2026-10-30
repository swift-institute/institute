internal import Institute_Linter_Rule_Manifest
public import Lint
public import Institute_Model
internal import SwiftSyntax

extension Lint.Rule {
    public static let `libc import in composition` = Lint.Rule.`libc import in composition`(in: nil)

    public static func `libc import in composition`(
        in repository: Institute.Repository.Coordinate?
    ) -> Lint.Rule {
        Lint.Rule(
            id: "libc import in composition",
            default: .warning,
            controls: platformLibcImportControls(in: repository),
            observe: { source, severity in
                guard repository?.organization.layer == .compositions,
                    let target = manifestSourceTarget(ofPath: source.file.filePath),
                    !target.hasSuffix("Shims")
                else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
                }
                let visitor = PlatformLibcImportVisitor(
                    source: source.file,
                    severity: severity,
                    converter: source.converter
                )
                visitor.walk(source.tree)
                return Lint.Rule.Observation(findings: visitor.matches, coverage: .measured)
            }
        )
    }
}

private func platformLibcImportControls(
    in repository: Institute.Repository.Coordinate?
) -> [Lint.Rule.Control] {
    let root = "/workspace/\(repository?.name ?? "swift-package")"
    guard repository?.organization.layer == .compositions else {
        return [
            .init(
                id: "libc import in composition outside compositions",
                source: "internal import Darwin",
                path: "\(root)/Sources/Kernel/Kernel.swift",
                expectation: .clean,
                applicability: .inapplicable
            )
        ]
    }
    return [
        .init(
            id: "libc import in composition darwin",
            source: "#if canImport(Darwin)\ninternal import Darwin\n#elseif canImport(Glibc)\ninternal import Glibc\n#endif",
            path: "\(root)/Sources/Kernel File/Kernel.Copy.Error+posixErrno.swift",
            expectation: .findings(2)
        ),
        .init(
            id: "libc import in composition submodule",
            source: "import WinSDK.WinSock2",
            path: "\(root)/Sources/Sockets/Socket.swift",
            expectation: .findings(1)
        ),
        .init(
            id: "libc import in composition kernel surface",
            source: "public import Kernel\nimport ISO_9945_Core",
            path: "\(root)/Sources/Kernel File/Kernel.Copy.swift",
            expectation: .clean
        ),
        .init(
            id: "libc import in composition shim target",
            source: "internal import Musl",
            path: "\(root)/Sources/Process Shims/Shim.swift",
            expectation: .clean,
            applicability: .inapplicable
        ),
        .init(
            id: "libc import in composition shim near miss",
            source: "internal import Musl",
            path: "\(root)/Sources/Process/Shims.swift",
            expectation: .findings(1)
        ),
        .init(
            id: "libc import in composition tests",
            source: "import Darwin",
            path: "\(root)/Tests/Kernel Tests/Fixture.swift",
            expectation: .clean,
            applicability: .inapplicable
        ),
        .init(
            id: "libc import in composition bare filename",
            source: "import Darwin",
            path: "Kernel.swift",
            expectation: .clean,
            applicability: .inapplicable
        ),
    ]
}

private let platformLibcModules: Swift::Set<Swift::String> = ["Glibc", "Darwin", "Musl", "WinSDK", "ucrt"]

internal final class PlatformLibcImportVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let module = node.path.first?.name.text, platformLibcModules.contains(module) else {
            return .skipChildren
        }
        let location = converter.location(for: node.path.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "libc import in composition",
                message: "[libc import in composition] [PLAT-ARCH-009]: a compositions package imports "
                    + "the C library `\(module)` directly. The C library is the Standards' surface: "
                    + "the constant or call this file needs belongs in the Standard that encodes it "
                    + "(errno codes in `swift-iso-9945`'s `Error.Code`, Darwin calls in "
                    + "`swift-darwin-standard`), reached through the platform package. Only a "
                    + "`… Shims` target may import it here."
            )
        )
        return .skipChildren
    }
}
