public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `unchecked sendable revalidation anchor` = Lint.Rule(
        id: "unchecked sendable revalidation anchor",
        default: .warning,
        controls: [
            .init(
                id: "unchecked sendable revalidation anchor incomplete",
                source: "// WHY: Category D — compiler workaround.\nextension Container: @unchecked Sendable {}",
                path: "Sources/Memory Core/IncompleteRevalidationAnchor.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unchecked sendable revalidation anchor complete",
                source: "// WHY: Category D — compiler workaround.\n// WHEN TO REMOVE: When structural inference lands.\n// TRACKING: issue-1.\nextension Container: @unchecked Sendable {}",
                path: "Sources/Memory Core/CompleteRevalidationAnchor.swift",
                expectation: .clean
            ),
            .init(
                id: "unchecked sendable revalidation anchor semantic",
                source: "// Callers externally synchronize access.\nextension Container: @unchecked Sendable {}",
                path: "Sources/Memory Core/SemanticSendable.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = MemoryUncheckedSendableRevalidationAnchorVisitor(
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
internal let memoryUncheckedSendableRevalidationAnchorMessage: Swift::String =
    "[unchecked sendable revalidation anchor] [MEM-SEND-006]: "
    + "`@unchecked Sendable` whose justification cites a compiler limitation "
    + "MUST carry a revalidation anchor in the declaration's leading trivia. "
    + "Required markers: `WHY:` (the limitation), `WHEN TO REMOVE:` (the "
    + "toolchain / compiler-fix trigger), `TRACKING:` (the experiment path or "
    + "issue link). Without these, the justification ages into folklore as "
    + "compilers fix the underlying limitation. If the conformance is NOT "
    + "compiler-limitation-justified, drop the limitation-citing language from "
    + "the comment block — this rule fires only when limitation indicators "
    + "(`compiler`, `until Swift`, `Sendable workaround`, `Category D`, "
    + "`@_rawLayout`, `WORKAROUND`) are present in the declaration's full "
    + "leading trivia (not just the line immediately above it)."

internal final class MemoryUncheckedSendableRevalidationAnchorVisitor: SyntaxVisitor {
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

    private func hasUncheckedAttribute(_ inherited: InheritedTypeSyntax) -> Bool {
        if let attributed = inherited.type.as(AttributedTypeSyntax.self) {
            for attribute in attributed.attributes {
                guard let attr = attribute.as(AttributeSyntax.self) else { continue }
                if attr.attributeName.trimmedDescription == "unchecked" {
                    return true
                }
            }
        }
        return false
    }

    private func isSendableInherited(_ inherited: InheritedTypeSyntax) -> Bool {
        var current = inherited.type
        while let attributed = current.as(AttributedTypeSyntax.self) {
            current = attributed.baseType
        }
        if let identifier = current.as(IdentifierTypeSyntax.self) {
            return identifier.name.text == "Sendable"
        }
        if let member = current.as(MemberTypeSyntax.self) {
            return member.name.text == "Sendable"
        }
        return false
    }

    private func collectCommentText(_ trivia: Trivia) -> Swift::String {
        var collected: Swift::String = ""
        for piece in trivia {
            switch piece {
            case .lineComment(let text),
                .blockComment(let text),
                .docLineComment(let text),
                .docBlockComment(let text):
                collected.append(text)
                collected.append("\n")

            default:
                continue
            }
        }
        return collected
    }

    private func hasCompilerLimitationIndicator(_ text: Swift::String) -> Bool {
        let lower = text.lowercased()

        if lower.contains("compiler") {
            let verbs = [
                "cannot", "can't", "cant",
                "doesn't", "doesnt",
                "won't", "wont",
                "limitation",
                "infer",
                "prove",
            ]
            for verb in verbs where lower.contains(verb) {
                return true
            }
        }

        if lower.contains("until swift") { return true }
        if lower.contains("@_rawlayout") { return true }
        if lower.contains("workaround") { return true }

        if lower.contains("category d") {
            return true
        }

        return false
    }

    fileprivate struct AnchorPresence {
        var why: Bool = false
        var whenToRemove: Bool = false
        var tracking: Bool = false
    }

    private func anchorPresence(_ text: Swift::String) -> AnchorPresence {
        let lower = text.lowercased()
        return AnchorPresence(
            why: lower.contains("why:"),
            whenToRemove: lower.contains("when to remove:"),
            tracking: lower.contains("tracking:")
        )
    }

    private func emit(at inherited: InheritedTypeSyntax, missing: [Swift::String]) {
        let location = converter.location(for: inherited.positionAfterSkippingLeadingTrivia)
        let missingList: Swift::String
        if missing.isEmpty {
            missingList = ""
        } else {
            missingList = " Missing: " + missing.joined(separator: ", ") + "."
        }
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "unchecked sendable revalidation anchor",
                message: memoryUncheckedSendableRevalidationAnchorMessage + missingList
            )
        )
    }

    private func check(
        declaration: some DeclSyntaxProtocol,
        inheritanceClause: InheritanceClauseSyntax?
    ) {
        guard let inheritanceClause else { return }

        var triggers: [InheritedTypeSyntax] = []
        for inherited in inheritanceClause.inheritedTypes {
            guard isSendableInherited(inherited) else { continue }
            guard hasUncheckedAttribute(inherited) else { continue }
            triggers.append(inherited)
        }
        guard !triggers.isEmpty else { return }

        let trivia = declaration.leadingTrivia
        let commentText = collectCommentText(trivia)

        guard hasCompilerLimitationIndicator(commentText) else { return }

        let presence = anchorPresence(commentText)
        guard !presence.isComplete else { return }

        for trigger in triggers {
            emit(at: trigger, missing: presence.missingMarkers)
        }
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        check(declaration: node, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        check(declaration: node, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        check(declaration: node, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        check(declaration: node, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        check(declaration: node, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }
}

extension MemoryUncheckedSendableRevalidationAnchorVisitor.AnchorPresence {
    var isComplete: Bool { why && whenToRemove && tracking }

    var missingMarkers: [Swift::String] {
        var missing: [Swift::String] = []
        if !why { missing.append("WHY:") }
        if !whenToRemove { missing.append("WHEN TO REMOVE:") }
        if !tracking { missing.append("TRACKING:") }
        return missing
    }
}
