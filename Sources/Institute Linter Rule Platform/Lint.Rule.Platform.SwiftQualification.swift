public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `swift protocol qualification` = Lint.Rule(
        id: "swift protocol qualification",
        default: .warning,
        controls: [
            .init(
                id: "swift protocol qualification bare sequence",
                source: "func consume(_ values: some Sequence<Int>) {}",
                path: "Sources/Platform Core/BareSequence.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "swift protocol qualification qualified sequence",
                source: "func consume(_ values: some Swift.Sequence<Int>) {}",
                path: "Sources/Platform Core/QualifiedSequence.swift",
                expectation: .clean
            ),
            .init(
                id: "swift protocol qualification module selector",
                source: "func consume(_ values: some Swift::Sequence<Int>) {}",
                path: "Sources/Platform Core/SelectorSequence.swift",
                expectation: .clean
            ),
            .init(
                id: "swift protocol qualification module selector error",
                source: "func handle<E: Swift::Error>(_ error: E) {}",
                path: "Sources/Platform Core/SelectorError.swift",
                expectation: .clean
            ),
            .init(
                id: "swift protocol qualification foreign module sequence",
                source: "func consume(_ values: some Other::Sequence<Int>) {}",
                path: "Sources/Platform Core/ForeignSequence.swift",
                expectation: .clean
            ),
            .init(
                id: "swift protocol qualification foreign module error",
                source: "func handle<E: Other::Error>(_ error: E) {}",
                path: "Sources/Platform Core/ForeignError.swift",
                expectation: .clean
            ),
            .init(
                id: "swift protocol qualification declared foreign dotted error",
                source: "enum Other { protocol Error {} }\nfunc handle<E: Other.Error>(_ error: E) {}",
                path: "Sources/Platform Core/DeclaredForeignError.swift",
                expectation: .clean
            ),
            .init(
                id: "swift protocol qualification bare error",
                source: "func handle<E: Error>(_ error: E) {}",
                path: "Sources/Platform Core/BareError.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "swift protocol qualification stdlib extension boundary",
                source: "extension Array { func consume(_ values: some Sequence<Int>) {} }",
                path: "Sources/Platform Core/ArrayExtension.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = PlatformSwiftQualificationVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        },
        repair: { source in
            guard let contents = platformSwiftQualificationFixed(source) else { return .unchanged }
            return .edits([.rewrite(path: source.path, contents: contents)])
        }
    )
}

@usableFromInline
internal let platformSwiftQualificationShadowedProtocols: Swift::Set<Swift::String> = [
    "Sequence",
    "Collection",
    "Error",
]

@usableFromInline
internal let platformSwiftQualificationStdlibShadowingTypes: Swift::Set<Swift::String> = [
    "Set",
    "Array",
    "ArraySlice",
    "ContiguousArray",
    "Dictionary",
    "String",
    "Substring",
    "Optional",
    "Result",
    "Range",
    "ClosedRange",
    "CollectionOfOne",
    "EmptyCollection",
    "KeyValuePairs",
    "ReversedCollection",
    "UnsafePointer",
    "UnsafeMutablePointer",
    "UnsafeRawPointer",
    "UnsafeMutableRawPointer",
    "UnsafeBufferPointer",
    "UnsafeMutableBufferPointer",
]

internal func platformSwiftQualificationIsInsideStdlibExtension(_ node: Syntax) -> Swift::Bool {
    var current: Syntax? = node.parent
    while let candidate = current {
        if let ext = candidate.as(ExtensionDeclSyntax.self) {
            if let identifier = ext.extendedType.as(IdentifierTypeSyntax.self),
                platformSwiftQualificationStdlibShadowingTypes.contains(identifier.name.text)
            {
                return true
            }
            if let member = ext.extendedType.as(MemberTypeSyntax.self),
                platformSwiftQualificationStdlibShadowingTypes.contains(member.name.text),
                let base = member.baseType.as(IdentifierTypeSyntax.self),
                base.name.text == "Swift"
            {
                return true
            }
            return false
        }
        current = candidate.parent
    }
    return false
}

@usableFromInline
internal let platformSwiftQualificationMessage: Swift::String =
    "[swift protocol qualification] [PLAT-ARCH-022]: stdlib-shadowing "
    + "protocol reference is unqualified. Use `Swift::<Protocol>` (or `Swift.<Protocol>`) form "
    + "(e.g., `some Swift.Sequence<UInt8>` not `some Sequence<UInt8>`; "
    + "`<E: Swift.Error>` not `<E: Error>`). Shadowing namespaces "
    + "(`swift-sequence.Sequence`, per-package `Module.Error`) "
    + "make the bare name resolve to the institute namespace, not the "
    + "stdlib protocol."

internal func platformSwiftQualificationBareShadowedLeaves(
    in type: TypeSyntax
) -> [(name: Swift::String, position: AbsolutePosition)] {
    var results: [(name: Swift::String, position: AbsolutePosition)] = []
    var stack: [TypeSyntax] = [type]
    while let next = stack.popLast() {
        var current = next
        while let optional = current.as(OptionalTypeSyntax.self) {
            current = optional.wrappedType
        }
        while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            current = iuo.wrappedType
        }
        while let attributed = current.as(AttributedTypeSyntax.self) {
            current = attributed.baseType
        }
        if let composition = current.as(CompositionTypeSyntax.self) {
            for element in composition.elements {
                stack.append(element.type)
            }
            continue
        }
        if let someAny = current.as(SomeOrAnyTypeSyntax.self) {
            stack.append(someAny.constraint)
            continue
        }
        if let identifier = current.as(IdentifierTypeSyntax.self) {
            let name = identifier.name.text
            if platformSwiftQualificationShadowedProtocols.contains(name), identifier.moduleSelector == nil {
                results.append(
                    (name: name, position: identifier.name.positionAfterSkippingLeadingTrivia)
                )
            }
            continue
        }
    }
    return results
}

internal final class PlatformSwiftQualificationVisitor: SyntaxVisitor {
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

    private func emit(at position: AbsolutePosition) {
        let location = converter.location(for: position)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "swift protocol qualification",
                message: platformSwiftQualificationMessage
            )
        )
    }

    private func check(_ type: TypeSyntax) {
        for leaf in platformSwiftQualificationBareShadowedLeaves(in: type) {
            emit(at: leaf.position)
        }
    }

    override func visit(_ node: InheritedTypeSyntax) -> SyntaxVisitorContinueKind {
        if platformSwiftQualificationIsInsideStdlibExtension(Syntax(node)) {
            return .visitChildren
        }
        check(node.type)
        return .visitChildren
    }

    override func visit(_ node: GenericParameterSyntax) -> SyntaxVisitorContinueKind {
        if platformSwiftQualificationIsInsideStdlibExtension(Syntax(node)) {
            return .visitChildren
        }
        if let inherited = node.inheritedType {
            check(inherited)
        }
        return .visitChildren
    }

    override func visit(_ node: ConformanceRequirementSyntax) -> SyntaxVisitorContinueKind {
        if platformSwiftQualificationIsInsideStdlibExtension(Syntax(node)) {
            return .visitChildren
        }
        check(node.rightType)
        return .visitChildren
    }

    override func visit(_ node: SomeOrAnyTypeSyntax) -> SyntaxVisitorContinueKind {
        if platformSwiftQualificationIsInsideStdlibExtension(Syntax(node)) {
            return .visitChildren
        }
        check(node.constraint)
        return .visitChildren
    }
}
