public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `performance suite serialized` = Lint.Rule(
        id: "performance suite serialized",
        default: .warning,
        controls: [
            .init(
                id: "performance suite serialized missing trait",
                source: "@Suite struct Performance {}",
                path: "Tests/Testing Tests/Performance Tests.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "performance suite serialized trait",
                source: "@Suite(.serialized) struct Performance {}",
                path: "Tests/Testing Tests/Performance Tests.swift",
                expectation: .clean
            ),
            .init(
                id: "performance suite serialized different suite",
                source: "@Suite struct Benchmark {}",
                path: "Tests/Testing Tests/Benchmark Tests.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = TestingPerformanceSuiteSerializedVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let testingPerformanceSuiteSerializedMessage: Swift::String =
    "[performance suite serialized] [SWIFT-TEST-004]: performance suites MUST "
    + "carry `.serialized` to prevent parallel execution variance from polluting "
    + "timing measurements."

internal final class TestingPerformanceSuiteSerializedVisitor: SyntaxVisitor {
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

    private func suiteAttribute(_ attributes: AttributeListSyntax) -> AttributeSyntax? {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "Suite" { return attr }
        }
        return nil
    }

    private func mentionsSerialized(_ attribute: AttributeSyntax) -> Swift::Bool {
        guard case .argumentList(let arguments) = attribute.arguments else { return false }
        for argument in arguments {
            if let member = argument.expression.as(MemberAccessExprSyntax.self),
                member.declName.baseName.text == "serialized"
            {
                return true
            }
        }
        return false
    }

    private func hasTestFunction(_ members: MemberBlockItemListSyntax) -> Swift::Bool {
        for member in members {
            guard let function = member.decl.as(FunctionDeclSyntax.self) else { continue }
            for attribute in function.attributes {
                guard let attr = attribute.as(AttributeSyntax.self) else { continue }
                if attr.attributeName.trimmedDescription == "Test" { return true }
            }
        }
        return false
    }

    private func check(
        name: TokenSyntax,
        attributes: AttributeListSyntax,
        members: MemberBlockItemListSyntax
    ) {
        guard name.text == "Performance" else { return }
        if let attribute = suiteAttribute(attributes) {
            guard !mentionsSerialized(attribute) else { return }
        } else {
            guard hasTestFunction(members) else { return }
        }
        let location = converter.location(for: name.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "performance suite serialized",
                message: testingPerformanceSuiteSerializedMessage
            )
        )
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, attributes: node.attributes, members: node.memberBlock.members)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, attributes: node.attributes, members: node.memberBlock.members)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, attributes: node.attributes, members: node.memberBlock.members)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, attributes: node.attributes, members: node.memberBlock.members)
        return .visitChildren
    }
}
