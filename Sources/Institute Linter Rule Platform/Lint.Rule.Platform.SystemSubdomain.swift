public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `system subdomain` = Lint.Rule(
        id: "system subdomain",
        default: .warning,
        controls: [
            .init(
                id: "system subdomain platform-qualified extension",
                source: "extension Darwin.System { public static func probe() {} }",
                path: "Sources/Platform Core/DarwinSystem.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "system subdomain direct system extension",
                source: "extension System { public static func probe() {} }",
                path: "Sources/Platform Core/System.swift",
                expectation: .clean
            ),
            .init(
                id: "system subdomain file system domain",
                source: "extension Windows.`32`.Kernel.File.System { public enum Stats {} }",
                path: "Sources/Platform Core/FileSystem.swift",
                expectation: .clean
            ),
            .init(
                id: "system subdomain nonplatform parent",
                source: "public enum Domain { public enum System {} }",
                path: "Sources/Platform Core/DomainSystem.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = PlatformSystemSubdomainVisitor(
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
internal let platformSystemSubdomainMessage: Swift::String =
    "[system subdomain] [PLAT-ARCH-026]: `System` must NOT be "
    + "a subdomain of `Darwin` / `Linux` / `Windows`. Platform System "
    + "targets extend the cross-platform `System` namespace directly "
    + "— platform-specific discovery (sysctl, /proc/meminfo, WinSDK) "
    + "is mechanism, not a new domain. Nesting forces Core to be "
    + "published per [PLAT-ARCH-027]; the variant `@_exported` re-"
    + "export carries the namespace without that publication step."

private func platformSystemSubdomainRootIdentifier(_ type: TypeSyntax) -> Swift::String? {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return identifier.name.text
    }
    if let member = type.as(MemberTypeSyntax.self) {
        return platformSystemSubdomainRootIdentifier(member.baseType)
    }
    return nil
}

internal func platformSystemSubdomainIsPlatformSystemMemberType(
    _ type: TypeSyntax
) -> AbsolutePosition? {
    guard let member = type.as(MemberTypeSyntax.self) else { return nil }
    guard member.name.text == "System" else { return nil }
    if let parent = member.baseType.as(MemberTypeSyntax.self), parent.name.text == "File" {
        return nil
    }
    guard let root = platformSystemSubdomainRootIdentifier(member.baseType) else {
        return nil
    }
    guard platformPlatformTokens.contains(root) else { return nil }
    return member.name.positionAfterSkippingLeadingTrivia
}

internal final class PlatformSystemSubdomainVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var nameStack: [Swift::String] = []

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
                identifier: "system subdomain",
                message: platformSystemSubdomainMessage
            )
        )
    }

    private static func extensionLeafName(_ type: TypeSyntax) -> Swift::String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text
        }
        return nil
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if let position = platformSystemSubdomainIsPlatformSystemMemberType(
            node.extendedType
        ) {
            emit(at: position)
        }
        nameStack.append(Self.extensionLeafName(node.extendedType) ?? "")
        return .visitChildren
    }
    override func visitPost(_: ExtensionDeclSyntax) { nameStack.removeLast() }

    private func checkSystemName(_ name: TokenSyntax) {
        guard name.text == "System" else { return }
        guard let last = nameStack.last,
            platformPlatformTokens.contains(last)
        else { return }
        emit(at: name.positionAfterSkippingLeadingTrivia)
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSystemName(node.name)
        nameStack.append(node.name.text)
        return .visitChildren
    }
    override func visitPost(_: EnumDeclSyntax) { nameStack.removeLast() }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSystemName(node.name)
        nameStack.append(node.name.text)
        return .visitChildren
    }
    override func visitPost(_: StructDeclSyntax) { nameStack.removeLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSystemName(node.name)
        nameStack.append(node.name.text)
        return .visitChildren
    }
    override func visitPost(_: ClassDeclSyntax) { nameStack.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSystemName(node.name)
        nameStack.append(node.name.text)
        return .visitChildren
    }
    override func visitPost(_: ActorDeclSyntax) { nameStack.removeLast() }
}
