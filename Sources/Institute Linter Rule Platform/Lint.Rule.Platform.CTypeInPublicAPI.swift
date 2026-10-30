public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `c type in public api` = Lint.Rule(
        id: "c type in public api",
        default: .warning,
        controls: [
            .init(
                id: "c type in public api exposed kevent",
                source: "public func register(events: [kevent]) {}",
                path: "Sources/Platform Core/ExposedKevent.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "c type in public api ecosystem wrapper",
                source: "public func register(events: [Kernel.Kqueue.Event]) {}",
                path: "Sources/Platform Core/WrappedEvent.swift",
                expectation: .clean
            ),
            .init(
                id: "c type in public api internal boundary",
                source: "internal func register(event: kevent) {}",
                path: "Sources/Platform Core/InternalKevent.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = PlatformCTypeInPublicAPIVisitor(
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
internal let platformCTypeInPublicAPIMessage: Swift::String =
    "[c type in public api] [PLAT-ARCH-005a]: platform C type appears in "
    + "public API signature. Public APIs in the platform stack MUST wrap "
    + "every C type in an ecosystem type at L1 so consumers never need to "
    + "import the platform C module. The flagged identifier is one of the "
    + "canonical leak patterns (`kevent`, `epoll_event`, `OVERLAPPED`, "
    + "`sockaddr`, `HANDLE`, etc.)."

internal let platformCTypeInPublicAPIFlaggedCTypes: Swift::Set<Swift::String> = [
    "kevent", "epoll_event", "OVERLAPPED", "sockaddr", "iovec",
    "io_uring_sqe", "io_uring_cqe", "timespec", "pid_t",
    "HANDLE", "DWORD", "WCHAR", "BOOL", "LPVOID", "WSABUF",
    "msghdr", "cmsghdr", "ifreq", "sockaddr_in", "sockaddr_in6",
    "sockaddr_un", "stat", "statfs", "dirent", "passwd",
]

internal func platformCTypeInPublicAPIContainsCType(_ type: TypeSyntax) -> Swift::Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        if platformCTypeInPublicAPIFlaggedCTypes.contains(identifier.name.text) {
            return true
        }
        if let arguments = identifier.genericArgumentClause {
            for argument in arguments.arguments {
                if case .type(let argType) = argument.argument,
                    platformCTypeInPublicAPIContainsCType(argType)
                {
                    return true
                }
            }
        }
        return false
    }
    if let optional = type.as(OptionalTypeSyntax.self) {
        return platformCTypeInPublicAPIContainsCType(optional.wrappedType)
    }
    if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        return platformCTypeInPublicAPIContainsCType(iuo.wrappedType)
    }
    if let array = type.as(ArrayTypeSyntax.self) {
        return platformCTypeInPublicAPIContainsCType(array.element)
    }
    if let dictionary = type.as(DictionaryTypeSyntax.self) {
        return platformCTypeInPublicAPIContainsCType(dictionary.key)
            || platformCTypeInPublicAPIContainsCType(dictionary.value)
    }
    if let attributed = type.as(AttributedTypeSyntax.self) {
        return platformCTypeInPublicAPIContainsCType(attributed.baseType)
    }
    if let someOrAny = type.as(SomeOrAnyTypeSyntax.self) {
        return platformCTypeInPublicAPIContainsCType(someOrAny.constraint)
    }
    if let metatype = type.as(MetatypeTypeSyntax.self) {
        return platformCTypeInPublicAPIContainsCType(metatype.baseType)
    }
    if let tuple = type.as(TupleTypeSyntax.self) {
        for element in tuple.elements {
            if platformCTypeInPublicAPIContainsCType(element.type) {
                return true
            }
        }
        return false
    }
    if let function = type.as(FunctionTypeSyntax.self) {
        for parameter in function.parameters {
            if platformCTypeInPublicAPIContainsCType(parameter.type) {
                return true
            }
        }
        return platformCTypeInPublicAPIContainsCType(function.returnClause.type)
    }
    if let member = type.as(MemberTypeSyntax.self) {
        if platformCTypeInPublicAPIFlaggedCTypes.contains(member.name.text) {
            return true
        }
        if let arguments = member.genericArgumentClause {
            for argument in arguments.arguments {
                if case .type(let argType) = argument.argument,
                    platformCTypeInPublicAPIContainsCType(argType)
                {
                    return true
                }
            }
        }
        return false
    }
    return false
}

internal final class PlatformCTypeInPublicAPIVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSignature(
            node: Syntax(node),
            modifiers: node.modifiers,
            signature: node.signature,
            emitAt: node.funcKeyword.positionAfterSkippingLeadingTrivia
        )
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSignature(
            node: Syntax(node),
            modifiers: node.modifiers,
            signature: node.signature,
            emitAt: node.initKeyword.positionAfterSkippingLeadingTrivia
        )
        return .visitChildren
    }

    private func checkSignature(
        node: Syntax,
        modifiers: DeclModifierListSyntax,
        signature: FunctionSignatureSyntax,
        emitAt position: AbsolutePosition
    ) {
        guard platformIsPublicAPIEffective(node, modifiers: modifiers) else {
            return
        }
        var hit = false
        for parameter in signature.parameterClause.parameters {
            if platformCTypeInPublicAPIContainsCType(parameter.type) {
                hit = true
                break
            }
        }
        if !hit, let returnType = signature.returnClause?.type,
            platformCTypeInPublicAPIContainsCType(returnType)
        {
            hit = true
        }
        guard hit else { return }
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
                identifier: "c type in public api",
                message: platformCTypeInPublicAPIMessage
            )
        )
    }
}
