public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `protocol sentinel under generic front door` = Lint.Rule(
        id: "protocol sentinel under generic front door",
        default: .warning,
        controls: [
            .init(
                id: "protocol sentinel under generic front door generic alias",
                source: "public typealias Array<Element> = __Array<Element>\n"
                    + "extension __Array { typealias `Protocol` = __ArrayProtocol }",
                path: "Sources/Structure Core/Array.Protocol.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "protocol sentinel under generic front door nominal carrier",
                source: "public struct Store {}\n"
                    + "extension Store { typealias `Protocol` = StoreProtocol }",
                path: "Sources/Structure Core/Store.Protocol.swift",
                expectation: .clean
            ),
            .init(
                id: "protocol sentinel under generic front door different carrier",
                source: "public typealias Array<Element> = __Array<Element>\n"
                    + "extension Store { typealias `Protocol` = StoreProtocol }",
                path: "Sources/Structure Core/Store.Protocol.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = StructureProtocolSentinelUnderGenericFrontDoorVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.resolvedMatches()
        }
    )
}

private let structureProtocolSentinelUnderGenericFrontDoorMessage: Swift::String =
    "[protocol sentinel under generic front door]: this `Protocol` "
    + "sentinel is nested under a carrier that a public GENERIC "
    + "top-level `typealias` fronts. Member-type lookup through an "
    + "unbound-generic-alias base never resolves a nested member on any "
    + "toolchain (swift-institute/Issues#81), so the front door's "
    + "consumer-facing spelling (`FrontDoor<T>.Protocol`) has no way to "
    + "reach this member — ruled unsupported in "
    + "swift-institute/.github#122 (disposition c). Hoist the protocol "
    + "to a non-generic top-level name instead (the `Store`/"
    + "`Storage<Allocation>` precedent in swift-storage), "
    + "retaining a non-generic compatibility alias if needed."

internal final class StructureProtocolSentinelUnderGenericFrontDoorVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    private var matches: [Diagnostic.Record] = []

    private var frontDoorCarrierNames: Swift::Set<Swift::String> = []

    private struct Candidate {
        let carrierName: Swift::String
        let position: AbsolutePosition
    }
    private var candidates: [Candidate] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.genericParameterClause != nil else { return .visitChildren }
        guard psgfdHasPublicOrOpen(node.modifiers) else { return .visitChildren }
        if let carrierName = psgfdLeafIdentifierName(node.initializer.value) {
            frontDoorCarrierNames.insert(carrierName)
        }
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let carrierName = psgfdLeafIdentifierName(node.extendedType) else {
            return .visitChildren
        }
        for member in node.memberBlock.members {
            guard let position = psgfdProtocolSentinelPosition(member.decl) else { continue }
            candidates.append(Candidate(carrierName: carrierName, position: position))
        }
        return .visitChildren
    }

    internal func resolvedMatches() -> [Diagnostic.Record] {
        for candidate in candidates {
            guard frontDoorCarrierNames.contains(candidate.carrierName) else { continue }
            let location = converter.location(for: candidate.position)
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "protocol sentinel under generic front door",
                    message: structureProtocolSentinelUnderGenericFrontDoorMessage
                )
            )
        }
        return matches
    }
}

private func psgfdHasPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Swift::Bool {
    for modifier in modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.public), .keyword(.open): return true
        default: continue
        }
    }
    return false
}

private func psgfdLeafIdentifierName(_ type: TypeSyntax) -> Swift::String? {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(identifier.name.text)
    }
    if let member = type.as(MemberTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(member.name.text)
    }
    return nil
}

private func psgfdProtocolSentinelPosition(_ decl: DeclSyntax) -> AbsolutePosition? {
    if let typealiasDecl = decl.as(TypeAliasDeclSyntax.self),
        structureIsProtocolSentinelName(typealiasDecl.name.text)
    {
        return typealiasDecl.name.positionAfterSkippingLeadingTrivia
    }
    if let structDecl = decl.as(StructDeclSyntax.self),
        structureIsProtocolSentinelName(structDecl.name.text)
    {
        return structDecl.name.positionAfterSkippingLeadingTrivia
    }
    if let enumDecl = decl.as(EnumDeclSyntax.self),
        structureIsProtocolSentinelName(enumDecl.name.text)
    {
        return enumDecl.name.positionAfterSkippingLeadingTrivia
    }
    if let classDecl = decl.as(ClassDeclSyntax.self),
        structureIsProtocolSentinelName(classDecl.name.text)
    {
        return classDecl.name.positionAfterSkippingLeadingTrivia
    }
    if let protocolDecl = decl.as(ProtocolDeclSyntax.self),
        structureIsProtocolSentinelName(protocolDecl.name.text)
    {
        return protocolDecl.name.positionAfterSkippingLeadingTrivia
    }
    return nil
}
