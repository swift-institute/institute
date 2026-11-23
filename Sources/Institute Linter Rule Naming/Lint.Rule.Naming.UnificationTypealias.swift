public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `unification typealias` = Lint.Rule(
        id: "unification typealias",
        default: .warning,
        controls: [
            .init(
                id: "unification typealias associated type witness",
                source: "public protocol Keyed { associatedtype HandlerKey }\n"
                    + "public struct Sample: Keyed {}\n"
                    + "extension Sample { public typealias HandlerKey = Handler.Key }",
                path: "Sources/Naming Core/Witness.swift",
                expectation: .clean
            ),
            .init(
                id: "unification typealias witness of a protocol declared elsewhere",
                source: "public struct Sample: Witness.Key {}\n"
                    + "extension Sample { public typealias Value = Handler.Key }",
                path: "Sources/Naming Core/ExternalWitness.swift",
                expectation: .clean
            ),
            .init(
                id: "unification typealias same name without a requirement",
                source: "public protocol Keyed { associatedtype Other }\n"
                    + "public struct Sample: Keyed {}\n"
                    + "extension Sample { public typealias HandlerKey = Handler.Key }",
                path: "Sources/Naming Core/Witness.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unification typealias different leaf",
                source: "public typealias SourceLocation = Text.Location",
                path: "Sources/Naming Core/DifferentLeaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unification typealias same leaf",
                source: "public typealias Event = Kernel.Event",
                path: "Sources/Naming Core/SameLeaf.swift",
                expectation: .clean
            ),
            .init(
                id: "unification typealias case-only leaf",
                source: "public typealias sRGB = IEC_61966.`2`.`1`.SRGB",
                path: "Sources/Naming Core/CaseOnlyLeaf.swift",
                expectation: .clean
            ),
            .init(
                id: "unification typealias quoted case-only leaf",
                source: "private typealias `event` = Kernel.Event",
                path: "Sources/Naming Core/QuotedCaseOnlyLeaf.swift",
                expectation: .clean
            ),
            .init(
                id: "unification typealias different letters",
                source: "public typealias sRGB = Color.SRGBA",
                path: "Sources/Naming Core/DifferentLetters.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unification typealias different underscore",
                source: "public typealias SR_GB = Color.SRGB",
                path: "Sources/Naming Core/DifferentUnderscore.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unification typealias private abbreviation",
                source: "private typealias Map = Dictionary.Ordered\nfunc f() { typealias Row = Table.Record }",
                path: "Sources/Naming Core/PrivateAbbreviation.swift",
                expectation: .clean
            ),
            .init(
                id: "unification typealias standard designation",
                source: "public typealias PDF = ISO.`32000`\ntypealias HTTP = IETF.RFC.`9110`",
                path: "Sources/Naming Core/Designation.swift",
                expectation: .clean
            ),
            .init(
                id: "unification typealias nested designation",
                source: "extension Sample { public typealias PDF = ISO.`32000` }",
                path: "Sources/Naming Core/NestedDesignation.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unification typealias element name",
                source: "public typealias linearGradient = SVG.Paint.Gradient.Linear\npublic typealias g = SVG.Document.Group",
                path: "Sources/Naming Core/ElementName.swift",
                expectation: .clean
            ),
            .init(
                id: "unification typealias unlisted compound",
                source: "public typealias linearRamp = SVG.Paint.Gradient.Linear",
                path: "Sources/Naming Core/UnlistedCompound.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unification typealias nested element name",
                source: "extension Sample { public typealias linearGradient = SVG.Paint.Gradient.Linear }",
                path: "Sources/Naming Core/NestedElementName.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unification typealias swift bridge",
                source: "public typealias Protocol = Swift.Equatable",
                path: "Sources/Naming Core/SwiftBridge.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingUnificationTypealiasVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                index: source.index
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingUnificationTypealiasMessage: Swift::String =
    "[unification typealias] [API-NAME-004]: typealias renames a "
    + "member type to a different local name. Type unification MUST use the "
    + "canonical type at all call sites; a typealias bridge adds indirection "
    + "without domain value."

internal final class NamingUnificationTypealiasVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let index: Lint.Source.Index
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        index: Lint.Source.Index
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.index = index
        super.init(viewMode: .sourceAccurate)
    }

    private func enclosingTypeName(of node: Syntax) -> Swift::String? {
        var current = node.parent
        while let candidate = current {
            if let decl = candidate.as(ExtensionDeclSyntax.self) {
                return decl.extendedType.trimmedDescription
            }
            if let decl = candidate.as(StructDeclSyntax.self) { return decl.name.text }
            if let decl = candidate.as(EnumDeclSyntax.self) { return decl.name.text }
            if let decl = candidate.as(ClassDeclSyntax.self) { return decl.name.text }
            if let decl = candidate.as(ActorDeclSyntax.self) { return decl.name.text }
            current = candidate.parent
        }
        return nil
    }

    /// Whether `type` conforms to a protocol this package does not declare, other than a standard one with no
    /// associated types. That protocol's associated types are unknown here, so a typealias on `type` may be the
    /// witness of one, as `typealias Value = Agent.Sessions` is for a `Witness.Key`.
    private func conformsToProtocolDeclaredElsewhere(_ type: Swift::String) -> Swift::Bool {
        index.reachableProtocols(of: type).contains { name in
            index.associatedTypes[name] == nil && !Self.standardWithoutAssociatedTypes.contains(name)
        }
    }

    /// Standard-library protocols that declare no associated type, so a typealias beside them witnesses nothing.
    private static let standardWithoutAssociatedTypes: Swift::Set<Swift::String> = [
        "Sendable", "SendableMetatype", "Equatable", "Hashable", "Comparable", "Codable", "Encodable", "Decodable",
        "Error", "CustomStringConvertible", "CustomDebugStringConvertible", "AnyObject", "Copyable", "Escapable",
        "BitwiseCopyable",
    ]

    /// An alias in a function, closure or accessor body abbreviates for that body only.
    private static func isLocal(_ syntax: Syntax) -> Swift::Bool {
        var current = syntax.parent
        while let candidate = current {
            if candidate.is(CodeBlockSyntax.self) || candidate.is(ClosureExprSyntax.self) { return true }
            if candidate.is(MemberBlockSyntax.self) || candidate.is(SourceFileSyntax.self) { return false }
            current = candidate.parent
        }
        return false
    }

    /// Whether `syntax` is declared at file scope, outside any type or extension.
    private static func isFileScope(_ syntax: Syntax) -> Swift::Bool {
        var current = syntax.parent
        while let candidate = current {
            if candidate.is(MemberBlockSyntax.self) || candidate.is(CodeBlockSyntax.self) { return false }
            if candidate.is(SourceFileSyntax.self) { return true }
            current = candidate.parent
        }
        return false
    }

    /// The element names of SVG 2 (W3C), verbatim. A file-scope alias that spells one of them names the element a DSL writes, as
    /// `typealias linearGradient = SVG.Paint.Gradient.Linear` does, not a second name for the type.
    private static let elementNames: Set<Swift::String> = [
        "a",
        "animate",
        "animateMotion",
        "animateTransform",
        "circle",
        "clipPath",
        "defs",
        "desc",
        "discard",
        "ellipse",
        "feBlend",
        "feColorMatrix",
        "feComponentTransfer",
        "feComposite",
        "feConvolveMatrix",
        "feDiffuseLighting",
        "feDisplacementMap",
        "feDistantLight",
        "feDropShadow",
        "feFlood",
        "feFuncA",
        "feFuncB",
        "feFuncG",
        "feFuncR",
        "feGaussianBlur",
        "feImage",
        "feMerge",
        "feMergeNode",
        "feMorphology",
        "feOffset",
        "fePointLight",
        "feSpecularLighting",
        "feSpotLight",
        "feTile",
        "feTurbulence",
        "filter",
        "foreignObject",
        "g",
        "image",
        "line",
        "linearGradient",
        "marker",
        "mask",
        "metadata",
        "mpath",
        "path",
        "pattern",
        "polygon",
        "polyline",
        "radialGradient",
        "rect",
        "script",
        "set",
        "stop",
        "style",
        "svg",
        "switch",
        "symbol",
        "text",
        "textPath",
        "title",
        "tspan",
        "use",
        "view",
    ]

    /// Whether `leaf` is a standard's designation, such as `32000` in `ISO.\`32000\``: a number, not a type's name.
    private static func isDesignation(_ leaf: Swift::String) -> Swift::Bool {
        let name = Lint.Syntax.Identifier.unescaped(leaf)
        return !name.isEmpty && name.allSatisfy(\.isNumber)
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let lhsName = node.name.text
        guard let member = node.initializer.value.as(MemberTypeSyntax.self) else {
            return .visitChildren
        }
        if member.genericArgumentClause != nil { return .visitChildren }
        if node.modifiers.contains(where: {
            $0.name.tokenKind == .keyword(.private) || $0.name.tokenKind == .keyword(.fileprivate)
        }) || Self.isLocal(Syntax(node)) {
            return .visitChildren
        }
        let rhsLeaf = member.name.text
        guard
            Lint.Syntax.Identifier.unescaped(rhsLeaf).lowercased()
                != Lint.Syntax.Identifier.unescaped(lhsName).lowercased()
        else { return .visitChildren }
        if let baseIdentifier = member.baseType.as(IdentifierTypeSyntax.self),
            baseIdentifier.name.text == "Swift"
        {
            return .visitChildren
        }
        if Naming.isInsideConformingContext(Syntax(node)) {
            return .visitChildren
        }
        if let owner = enclosingTypeName(of: Syntax(node)),
            index.witnessesAssociatedType(named: lhsName, on: owner)
                || conformsToProtocolDeclaredElsewhere(owner)
        {
            return .visitChildren
        }
        if Naming.isProtocolSentinel(rhsLeaf) {
            return .visitChildren
        }
        if Self.isDesignation(rhsLeaf), Self.isFileScope(Syntax(node)) {
            return .visitChildren
        }
        if Self.elementNames.contains(Lint.Syntax.Identifier.unescaped(lhsName)), Self.isFileScope(Syntax(node)) {
            return .visitChildren
        }
        let location = converter.location(
            for: node.typealiasKeyword.positionAfterSkippingLeadingTrivia
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
                identifier: "unification typealias",
                message: namingUnificationTypealiasMessage
            )
        )
        return .visitChildren
    }
}
