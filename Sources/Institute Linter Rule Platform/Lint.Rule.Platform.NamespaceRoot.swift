public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `compound platform namespace root` = Lint.Rule(
        id: "compound platform namespace root",
        default: .warning,
        controls: [
            .init(
                id: "compound platform namespace root top level",
                source: "public enum LinuxKernel {}",
                path: "Sources/Platform Core/LinuxKernel.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "compound platform namespace root shared namespace",
                source: "public enum Kernel {}",
                path: "Sources/Platform Core/Kernel.swift",
                expectation: .clean
            ),
            .init(
                id: "compound platform namespace root nested boundary",
                source: "public enum Outer { public enum LinuxKernel {} }",
                path: "Sources/Platform Core/NestedLinuxKernel.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = PlatformNamespaceRootVisitor(
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
internal let platformNamespaceRootMessage: Swift::String =
    "[compound platform namespace root] [PLAT-ARCH-003]: top-level "
    + "compound platform-prefix type (e.g., `LinuxKernel`, "
    + "`KqueueEventNotification`) fragments the kernel namespace. Extend "
    + "the shared `Kernel` namespace via `extension Kernel { ... }` so the "
    + "platform discriminator lives in the import, not the type name."

internal let platformNamespaceRootKernelKeywords: [Swift::String] = [
    "Kernel", "Kqueue", "Epoll", "IOCP", "IoUring", "EventNotification",
]

internal func platformNamespaceRootIsCompoundPlatformName(_ name: Swift::String) -> Swift::Bool {
    for prefix in platformPlatformTokens {
        guard name.hasPrefix(prefix) else { continue }
        let suffix = String(name.dropFirst(prefix.count))
        for keyword in platformNamespaceRootKernelKeywords {
            if suffix.hasPrefix(keyword) {
                return true
            }
        }
    }
    for keyword in platformNamespaceRootKernelKeywords where keyword != "Kernel" {
        if name.hasPrefix(keyword) && name.count > keyword.count {
            let suffix = String(name.dropFirst(keyword.count))
            if let first = suffix.first, first.isUppercase {
                return true
            }
        }
    }
    return false
}

internal final class PlatformNamespaceRootVisitor: SyntaxVisitor {
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

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        if Lint.Syntax.Scope.isTopLevel(node) { flagIfCompound(node.name) }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if Lint.Syntax.Scope.isTopLevel(node) { flagIfCompound(node.name) }
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if Lint.Syntax.Scope.isTopLevel(node) { flagIfCompound(node.name) }
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        if Lint.Syntax.Scope.isTopLevel(node) { flagIfCompound(node.name) }
        return .visitChildren
    }

    private func flagIfCompound(_ name: TokenSyntax) {
        guard platformNamespaceRootIsCompoundPlatformName(name.text) else {
            return
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
                identifier: "compound platform namespace root",
                message: platformNamespaceRootMessage
            )
        )
    }
}
