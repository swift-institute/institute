public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `configuration before content` = Lint.Rule(
        id: "configuration before content",
        default: .warning,
        controls: [
            .init(
                id: "configuration before content middle",
                source: "func perform(on target: Target, options: Options, mode: Mode) {}",
                path: "Sources/Closure Core/MiddleConfiguration.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "configuration before content first",
                source: "func perform(options: Options, target: Target, mode: Mode) {}",
                path: "Sources/Closure Core/FirstConfiguration.swift",
                expectation: .clean
            ),
            .init(
                id: "configuration before content before closure",
                source: "func perform(target: Target, options: Options, body: () -> Void) {}",
                path: "Sources/Closure Core/ClosureConfiguration.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ClosureConfigurationPlacementVisitor(
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
internal let closureConfigurationPlacementMessage: Swift::String =
    "[configuration before content] [API-IMPL-014]: "
    + "configuration-bearing parameters (`Options`, `Configuration`, "
    + "`Context`) MUST sit at first OR last non-closure position. "
    + "Middle placement breaks SE-0286 forward-scan with trailing "
    + "closures and obscures the configuration's role (primary input "
    + "vs. modifier). Move the parameter to position 0 (primary input) "
    + "or to the last non-closure slot (modifier, with a default)."

internal let configurationSuffixes: Swift::Set<Swift::String> = [
    "Options",
    "Configuration",
    "Context",
]

internal func isConfigurationType(_ type: TypeSyntax) -> Swift::Bool {
    let current = closureStrippingWrapperTypes(type)
    if let identifier = current.as(IdentifierTypeSyntax.self) {
        return configurationSuffixes.contains(where: identifier.name.text.hasSuffix)
    }
    if let member = current.as(MemberTypeSyntax.self) {
        return configurationSuffixes.contains(where: member.name.text.hasSuffix)
    }
    return false
}

internal final class ClosureConfigurationPlacementVisitor: SyntaxVisitor {
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
                identifier: "configuration before content",
                message: closureConfigurationPlacementMessage
            )
        )
    }

    private func checkParameters(_ parameters: FunctionParameterListSyntax) {
        let nonClosureIndices: [Swift::Int] = parameters.enumerated().compactMap {
            index,
            parameter in
            isClosureType(parameter.type) ? nil : index
        }
        guard let firstNonClosure = nonClosureIndices.first,
            let lastNonClosure = nonClosureIndices.last
        else { return }
        for (index, parameter) in parameters.enumerated() {
            guard isConfigurationType(parameter.type) else { continue }
            if index == firstNonClosure || index == lastNonClosure {
                continue
            }
            emit(at: parameter.firstName.positionAfterSkippingLeadingTrivia)
        }
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }
}
