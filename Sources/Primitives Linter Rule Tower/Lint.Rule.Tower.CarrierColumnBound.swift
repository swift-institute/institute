public import Lint
internal import SwiftSyntax

extension Lint.Rule {

    public static let `carrier column bound` = Lint.Rule(
        id: "carrier column bound",
        default: .warning,
        controls: [
            .init(
                id: "carrier column bound inline composition",
                source: """
                    public struct __Array<S: Store.`Protocol` & Buffer.`Protocol` & ~Copyable>: ~Copyable {
                        var storage: S
                    }
                    """,
                path: "Controls/CarrierColumnBound.swift",
                expectation: .findings(1)
            )
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = CarrierColumnBoundVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let carrierColumnBoundMessage: Swift::String =
    "[carrier column bound] [DS-026]: this tower carrier binds its column "
    + "parameter S to a capability protocol (Store/Buffer/Storage.Protocol) ON "
    + "THE TYPE. Per [DS-025] the carrier is always __X<S: ~Copyable>; capability "
    + "bounds belong on the capability EXTENSIONS (extension __X where S: "
    + "Store.`Protocol` & Buffer.`Protocol`), never on the carrier — that is "
    + "composition, not refinement. Move the bound off the type declaration onto "
    + "the conditional extensions that need the seam. (Inherited cross-package "
    + "bounds and predicate parts (b)-(e) stay enforced by "
    + "Scripts/adt-decoupling-classify.py.)"

internal final class CarrierColumnBoundVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    private static let storageAxis: Swift::String = "S"

    private static let carrierFamilyRoots: Swift::Set<Swift::String> = [
        "Array", "Fixed", "Queue", "Deque", "SlotMap", "Stack", "Heap",
        "Tree", "Hash", "Set", "Dictionary", "Slab", "List", "Bitset",
    ]

    private static let capabilityBases: Swift::Set<Swift::String> = [
        "Store", "Buffer", "Storage",
    ]

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard isPublic(node.modifiers) else { return .visitChildren }
        guard isTowerCarrier(node) else { return .visitChildren }
        guard columnHasCapabilityBound(node) else { return .visitChildren }

        let token = node.name
        let location = converter.location(for: token.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "carrier column bound",
                message: carrierColumnBoundMessage
            )
        )
        return .visitChildren
    }

    private func isPublic(_ modifiers: DeclModifierListSyntax) -> Swift::Bool {
        modifiers.contains { $0.name.text == "public" }
    }

    private func isTowerCarrier(_ node: StructDeclSyntax) -> Swift::Bool {
        if node.name.text.hasPrefix("__") { return true }
        guard let root = rootNamespace(of: node) else { return false }
        return Self.carrierFamilyRoots.contains(root)
    }

    private func columnHasCapabilityBound(_ node: StructDeclSyntax) -> Swift::Bool {
        if let parameters = node.genericParameterClause?.parameters {
            for parameter in parameters
            where stripBackticks(parameter.name.text) == Self.storageAxis {
                if let inherited = parameter.inheritedType,
                    typeReferencesCapabilityProtocol(inherited)
                {
                    return true
                }
            }
        }
        if let requirements = node.genericWhereClause?.requirements {
            for requirement in requirements {
                guard case .conformanceRequirement(let conformance) = requirement.requirement
                else { continue }
                guard leafName(of: conformance.leftType) == Self.storageAxis else { continue }
                if typeReferencesCapabilityProtocol(conformance.rightType) {
                    return true
                }
            }
        }
        return false
    }

    private func typeReferencesCapabilityProtocol(_ type: TypeSyntax) -> Swift::Bool {
        if let composition = type.as(CompositionTypeSyntax.self) {
            return composition.elements.contains {
                typeReferencesCapabilityProtocol($0.type)
            }
        }
        if let member = type.as(MemberTypeSyntax.self) {
            let memberLeaf = stripBackticks(member.name.text)
            if memberLeaf == "Protocol",
                let base = baseIdentifier(of: member.baseType),
                Self.capabilityBases.contains(base)
            {
                return true
            }
            return false
        }
        return false
    }

    private func rootNamespace(of node: StructDeclSyntax) -> Swift::String? {
        var outermost: Swift::String? = node.name.text
        var current: Syntax? = node.parent
        while let ancestor = current {
            if let ext = ancestor.as(ExtensionDeclSyntax.self) {
                outermost = baseIdentifier(of: ext.extendedType)
            } else if let nominal = ancestor.asProtocol((any NamedDeclSyntax).self),
                ancestor.is(StructDeclSyntax.self) || ancestor.is(EnumDeclSyntax.self)
                    || ancestor.is(ClassDeclSyntax.self) || ancestor.is(ActorDeclSyntax.self)
            {
                outermost = nominal.name.text
            }
            current = ancestor.parent
        }
        return outermost.map(stripBackticks)
    }

    private func baseIdentifier(of type: TypeSyntax) -> Swift::String? {
        if let member = type.as(MemberTypeSyntax.self) {
            return baseIdentifier(of: member.baseType)
        }
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return stripBackticks(identifier.name.text)
        }
        return nil
    }

    private func leafName(of type: TypeSyntax) -> Swift::String {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return stripBackticks(identifier.name.text)
        }
        return ""
    }

    private func stripBackticks(_ text: Swift::String) -> Swift::String {
        var result = text
        if result.hasPrefix("`") { result.removeFirst() }
        if result.hasSuffix("`") { result.removeLast() }
        return result
    }
}
