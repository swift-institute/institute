public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `canimport conditional` = Lint.Rule(
        id: "canimport conditional",
        default: .warning,
        controls: [
            .init(
                id: "canimport conditional platform module",
                source: "#if canImport(Linux_Kernel)\nimport Linux_Kernel\n#endif",
                path: "Sources/Platform Core/LinuxAvailability.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "canimport conditional c library availability",
                source: "#if canImport(Glibc)\nimport Glibc\n#endif",
                path: "Sources/Platform Core/LibcAvailability.swift",
                expectation: .clean
            ),
            .init(
                id: "canimport conditional inside an os guard",
                source: "#if os(Linux)\n#if canImport(Linux_Kernel)\nimport Linux_Kernel\n#endif\n#endif",
                path: "Sources/Platform Core/Guarded.swift",
                expectation: .clean
            ),
            .init(
                id: "canimport conditional os boundary",
                source: "#if os(Linux)\nimport Glibc\n#endif",
                path: "Sources/Platform Core/OperatingSystem.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = PlatformPlatformConditionalVisitor(
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
internal let platformPlatformConditionalMessage: Swift::String =
    "[canimport conditional] [PATTERN-004a]: platform "
    + "identity check uses `#if canImport(...)` on a platform-prefixed "
    + "module — `canImport` evaluates against module resolution (varies "
    + "by build system); platform identity is what `#if os(...)` is "
    + "for (evaluates against the target triple). Reserve `canImport` "
    + "for module availability: optional feature modules (`SwiftUI`, "
    + "`Combine`, etc.) and the raw C-library trellis "
    + "(`#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)`), "
    + "which is genuine module availability — `os(Linux)` cannot "
    + "distinguish Glibc from Musl. Institute platform-prefixed modules "
    + "(`Darwin_Kernel_Standard` etc.) are the forbidden shape."

internal let platformPlatformConditionalCLibraryModules: Swift::Set<Swift::String> = [
    "Darwin",
    "Glibc",
    "Musl",
    "Bionic",
    "Android",
    "WASILibc",
    "WinSDK",
    "ucrt",
    "CRT",
]

internal let platformPlatformConditionalPlatformPrefixes: Swift::Set<Swift::String> =
    platformPlatformTokens.union(["Glibc", "Musl", "Bionic", "WinSDK"])

internal func platformPlatformConditionalIsPlatformModuleName(_ name: Swift::String) -> Swift::Bool {
    if platformPlatformConditionalCLibraryModules.contains(name) { return false }
    if platformPlatformConditionalPlatformPrefixes.contains(name) { return true }
    for prefix in platformPlatformConditionalPlatformPrefixes {
        if name.hasPrefix("\(prefix)_") { return true }
    }
    return false
}

internal final class PlatformPlatformConditionalVisitor: SyntaxVisitor {
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

    override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
        guard let condition = node.condition else { return .visitChildren }
        if Self.isPlatformGuarded(node) { return .visitChildren }
        checkCondition(condition)
        return .visitChildren
    }

    /// Nested inside `#if os(Linux)`, the platform is already decided:
    /// the module check only asks whether the package's own platform target is built.
    private static func isPlatformGuarded(_ clause: IfConfigClauseSyntax) -> Swift::Bool {
        func mentionsOS(_ condition: ExprSyntax?) -> Swift::Bool {
            guard let condition else { return false }
            return condition.tokens(viewMode: .sourceAccurate).contains { $0.text == "os" }
        }
        var current = clause.parent
        while let candidate = current {
            if let outer = candidate.as(IfConfigClauseSyntax.self), mentionsOS(outer.condition) { return true }
            current = candidate.parent
        }
        return false
    }

    private func rootModuleIdentifier(of expression: ExprSyntax) -> TokenSyntax? {
        if let identifier = expression.as(DeclReferenceExprSyntax.self) {
            return identifier.baseName
        }
        if let member = expression.as(MemberAccessExprSyntax.self) {
            guard let base = member.base else { return nil }
            return rootModuleIdentifier(of: base)
        }
        return nil
    }

    private func checkCondition(_ expression: ExprSyntax) {
        if let call = expression.as(FunctionCallExprSyntax.self) {
            if let callee = call.calledExpression.as(DeclReferenceExprSyntax.self),
                callee.baseName.text == "canImport"
            {
                if let argument = call.arguments.first,
                    let root = rootModuleIdentifier(of: argument.expression)
                {
                    if platformPlatformConditionalIsPlatformModuleName(root.text) {
                        let position = root.positionAfterSkippingLeadingTrivia
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
                                identifier: "canimport conditional",
                                message: platformPlatformConditionalMessage
                            )
                        )
                    }
                }
            }
        }
        if let sequence = expression.as(SequenceExprSyntax.self) {
            for element in sequence.elements {
                checkCondition(element)
            }
        }
        if let infix = expression.as(InfixOperatorExprSyntax.self) {
            checkCondition(infix.leftOperand)
            checkCondition(infix.rightOperand)
        }
        if let prefix = expression.as(PrefixOperatorExprSyntax.self) {
            checkCondition(prefix.expression)
        }
    }
}
