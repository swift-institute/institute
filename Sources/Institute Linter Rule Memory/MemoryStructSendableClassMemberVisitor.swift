internal import Lint
internal import SwiftSyntax

internal final class MemoryStructSendableClassMemberVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let declaredClassNames: Swift::Set<Swift::String>
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        declaredClassNames: Swift::Set<Swift::String>
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.declaredClassNames = declaredClassNames
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard memoryStructSendableClassMemberUncheckedSendable(node.inheritanceClause) else {
            return .visitChildren
        }
        for member in node.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }
            if memoryStructSendableClassMemberIsComputed(variable) {
                continue
            }
            for binding in variable.bindings {
                guard let annotation = binding.typeAnnotation else { continue }
                var isClassType = false
                if let identifier = annotation.type.as(IdentifierTypeSyntax.self) {
                    isClassType = memoryStructSendableClassMemberIsClassType(
                        identifier.name.text,
                        in: declaredClassNames
                    )
                } else if let memberType = annotation.type.as(MemberTypeSyntax.self) {
                    let dotted = memberType.trimmedDescription
                    isClassType =
                        memoryStructSendableClassMemberIsClassType(dotted, in: declaredClassNames)
                        || memoryStructSendableClassMemberIsClassType(
                            memberType.name.text,
                            in: declaredClassNames
                        )
                }
                if isClassType {
                    let location = converter.location(
                        for: variable.bindingSpecifier.positionAfterSkippingLeadingTrivia
                    )
                    matches.append(
                        Diagnostic.Record(
                            location: Source.Location(
                                fileID: source.fileID,
                                filePath: source.filePath,
                                line: location.line,
                                column: location.column
                            ),
                            severity: severity,
                            identifier: "sendable struct with class member",
                            message: memoryStructSendableClassMemberMessage
                        )
                    )
                }
            }
        }
        return .visitChildren
    }
}
