internal import Institute_Linter_Rule_Manifest
public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `test file suffix` = Lint.Rule(
        id: "test file suffix",
        default: .warning,
        controls: [
            .init(
                id: "test file suffix upstream licensed package",
                source: "@Suite struct ValueTests {}",
                path: "Tests/Testing Tests/ValueTests.swift",
                expectation: .clean,
                license: .text("MIT License\n\nCopyright (c) 2025 Point-Free, Inc.\n\nPermission is hereby granted")
            ),
            .init(
                id: "test file suffix joined suffix",
                source: "@Suite struct ValueTests {}",
                path: "Tests/Testing Tests/ValueTests.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "test file suffix spaced suffix",
                source: "@Suite struct `Value Tests` {}",
                path: "Tests/Testing Tests/Value Tests.swift",
                expectation: .clean
            ),
            .init(
                id: "test file suffix production scope",
                source: "@Suite struct ValueTests {}",
                path: "Sources/Testing Support/ValueTests.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            if manifestLicenseIsUpstream(source.index.license) { return [] }
            let filePath = source.file.filePath
            let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
            guard components.contains("Tests") else { return [] }
            guard !components.contains(where: { $0.hasPrefix(".") }) else { return [] }
            guard
                let filename = components.last,
                filename.hasSuffix(".swift")
            else {
                return []
            }
            let basename = Swift::String(filename.dropLast(".swift".count))
            let hasExactlyOneSpaceBeforeTests =
                basename.hasSuffix(" Tests") && !basename.hasSuffix("  Tests")
            guard !hasExactlyOneSpaceBeforeTests else { return [] }
            let finder = TestingFileSuffixDeclarationFinder(viewMode: .sourceAccurate)
            finder.walk(source.tree)
            guard let position = finder.first else { return [] }
            let location = source.converter.location(for: position)
            return [
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "test file suffix",
                    message: testingFileSuffixMessage(basename: basename)
                )
            ]
        }
    )
}

@usableFromInline
internal func testingFileSuffixMessage(basename: Swift::String) -> Swift::String {
    "[test file suffix] [TEST-009]: test file '\(basename).swift' must end in "
        + "' Tests.swift'; rename to '\(testingFileSuffixRename(basename: basename)).swift'"
}

@usableFromInline
internal func testingFileSuffixRename(basename: Swift::String) -> Swift::String {
    func trimmed(_ string: Swift::Substring) -> Swift::Substring {
        var slice = string
        while slice.last == " " { slice = slice.dropLast() }
        return slice
    }
    let base = trimmed(basename[...])
    guard base.hasSuffix("Tests") else { return "\(base) Tests" }
    let subject = trimmed(base.dropLast("Tests".count))
    guard !subject.isEmpty else { return "\(base) Tests" }
    return "\(subject) Tests"
}

internal final class TestingFileSuffixDeclarationFinder: SyntaxVisitor {
    var first: AbsolutePosition?

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(attributes: node.attributes, name: "Suite", of: Syntax(node))
        return first == nil ? .visitChildren : .skipChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        record(attributes: node.attributes, name: "Suite", of: Syntax(node))
        return first == nil ? .visitChildren : .skipChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(attributes: node.attributes, name: "Suite", of: Syntax(node))
        return first == nil ? .visitChildren : .skipChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        record(attributes: node.attributes, name: "Suite", of: Syntax(node))
        return first == nil ? .visitChildren : .skipChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        record(attributes: node.attributes, name: "Test", of: Syntax(node))
        return .skipChildren
    }

    private func record(
        attributes: AttributeListSyntax,
        name: Swift::String,
        of node: Syntax
    ) {
        guard first == nil else { return }
        for attribute in attributes {
            guard case .attribute(let a) = attribute else { continue }
            let attributeName = a.attributeName.trimmedDescription
            if attributeName == name || attributeName.hasSuffix(".\(name)") {
                first = node.positionAfterSkippingLeadingTrivia
                return
            }
        }
    }
}
