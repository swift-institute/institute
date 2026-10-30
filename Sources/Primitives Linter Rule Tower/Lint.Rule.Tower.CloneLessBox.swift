public import Lint
internal import SwiftSyntax

extension Lint.Rule {

    public static let `clone-less box` = Lint.Rule(
        id: "clone-less box",
        default: .warning,
        controls: [
            .init(
                id: "clone-less box suppressed replacement",
                source: """
                    extension Dictionary where S: ~Copyable {
                        public mutating func removeAll<K: Swift.Hashable & ~Copyable, V: ~Copyable>()
                        where S == Shared<Hash.Entry<K, V>, Engine<K, V>> {
                            self.store = Shared(Engine<K, V>())
                        }
                    }
                    """,
                path: "Controls/CloneLessBox.swift",
                expectation: .findings(1)
            )
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = CloneLessBoxVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.finish()
        }
    )
}

private let cloneLessBoxMessage: Swift::String =
    "[clone-less box] [MEM-COPY-019]: this overload replaces a Shared box under "
    + "~Copyable element bounds with no implicitly-Copyable same-name twin in this "
    + "file. Overload resolution statically selects the strategy-less Shared init, so "
    + "the replacement box carries NO clone strategy even for concretely Copyable "
    + "elements — it works while unique and traps on the first post-fork mutation. "
    + "Split per the [MEM-COPY-017] pinned pair: add the Copyable-element twin "
    + "(suppression-free parameters) that rebuilds through the strategy-carrying init."

internal final class CloneLessBoxVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter

    private struct Candidate {
        let name: Swift::String
        let suppressed: Swift::Bool
        let assignsBox: Swift::Bool
        let token: TokenSyntax
    }
    private var candidates: [Candidate] = []

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

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        record(
            name: node.name.text,
            token: node.name,
            genericParameters: node.genericParameterClause,
            whereClause: node.genericWhereClause,
            body: node.body
        )
        return .skipChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        record(
            name: "init",
            token: node.initKeyword,
            genericParameters: node.genericParameterClause,
            whereClause: node.genericWhereClause,
            body: node.body
        )
        return .skipChildren
    }

    func finish() -> [Diagnostic.Record] {
        let twinNames = Swift::Set(candidates.filter { !$0.suppressed }.map(\.name))
        return
            candidates
            .filter { $0.suppressed && $0.assignsBox && !twinNames.contains($0.name) }
            .map { candidate in
                let location = converter.location(
                    for: candidate.token.positionAfterSkippingLeadingTrivia
                )
                return Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "clone-less box",
                    message: cloneLessBoxMessage
                )
            }
    }

    private func record(
        name: Swift::String,
        token: TokenSyntax,
        genericParameters: GenericParameterClauseSyntax?,
        whereClause: GenericWhereClauseSyntax?,
        body: CodeBlockSyntax?
    ) {
        guard let body else { return }
        candidates.append(
            Candidate(
                name: name,
                suppressed: suppressesOwnParameter(genericParameters, whereClause),
                assignsBox: assignsSharedBox(body),
                token: token
            )
        )
    }

    private func suppressesOwnParameter(
        _ genericParameters: GenericParameterClauseSyntax?,
        _ whereClause: GenericWhereClauseSyntax?
    ) -> Swift::Bool {
        guard let genericParameters else { return false }
        var ownNames: Swift::Set<Swift::String> = []
        for parameter in genericParameters.parameters {
            ownNames.insert(parameter.name.text)
            if let inherited = parameter.inheritedType, containsSuppressedCopyable(inherited) {
                return true
            }
        }
        guard let whereClause else { return false }
        for requirement in whereClause.requirements {
            guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self),
                let subject = conformance.leftType.as(IdentifierTypeSyntax.self),
                ownNames.contains(subject.name.text),
                containsSuppressedCopyable(conformance.rightType)
            else { continue }
            return true
        }
        return false
    }

    private func containsSuppressedCopyable(_ type: TypeSyntax) -> Swift::Bool {
        if let suppressed = type.as(SuppressedTypeSyntax.self) {
            return suppressed.type.trimmedDescription == "Copyable"
        }
        if let composition = type.as(CompositionTypeSyntax.self) {
            return composition.elements.contains { element in
                element.type.as(SuppressedTypeSyntax.self)?.type.trimmedDescription == "Copyable"
            }
        }
        return false
    }

    private func assignsSharedBox(_ body: CodeBlockSyntax) -> Swift::Bool {
        let finder = SharedBoxAssignmentFinder(viewMode: .sourceAccurate)
        finder.walk(body)
        return finder.found
    }
}
