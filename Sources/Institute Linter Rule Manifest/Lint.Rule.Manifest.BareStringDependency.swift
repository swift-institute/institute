internal import Byte
public import Lint
internal import SPM_Standard
internal import SwiftSyntax

extension Lint.Rule {
    public static let `bare string dependency` = Lint.Rule(
        id: "bare string dependency",
        default: .warning,
        controls: [
            .init(
                id: "bare string dependency manifest string",
                source: "let target = Target.target(name: \"Consumer\", dependencies: [\"Owner\"])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "bare string dependency manifest target",
                source: "let target = Target.target(name: \"Consumer\", "
                    + "dependencies: [.target(name: \"Owner\")])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "bare string dependency versioned manifest typed target",
                source: "let target = Target.target(name: \"Consumer\", "
                    + "dependencies: [.target(name: \"Owner\")])",
                path: "Package@swift-6.4.swift",
                expectation: .clean
            ),
            .init(
                id: "bare string dependency typed dependency accessor",
                source: "extension String { static let cssTheming: Self = \"CSS Theming\" }; "
                    + "extension Target.Dependency { static var cssTheming: Self { "
                    + ".target(name: .cssTheming) } }; "
                    + "let target = Target.target(name: \"Consumer\", dependencies: [.cssTheming])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "bare string dependency accessor hiding string",
                source: "extension Target.Dependency { static var owner: Self { \"Owner\" } }; "
                    + "let target = Target.target(name: \"Consumer\", dependencies: [.owner])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
        ],
        observe: { source, severity in
            guard manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description) else {
                return Lint.Rule.Observation(
                    findings: [],
                    coverage: .measured,
                    applicability: .inapplicable
                )
            }
            if let shape = manifestUnmeasurableShape(source.tree) {
                return Lint.Rule.Observation(
                    findings: [],
                    coverage: .unmeasured(.unsupportedSourceShape(shape))
                )
            }
            let visitor = ManifestBareStringDependencyVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.collectFileScopeBindings(source.tree)
            visitor.walk(source.tree)
            let coverage: Lint.Rule.Coverage =
                visitor.unhandledSourceShape.map {
                    .unmeasured(.unsupportedSourceShape($0))
                } ?? .measured
            return Lint.Rule.Observation(findings: visitor.matches, coverage: coverage)
        }
    )
}

@usableFromInline
internal func manifestIsPackageManifest(
    _ filePath: Swift::String,
    path: Swift::String,
    text: Swift::String
) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
    guard let filename = components.last else { return false }
    guard !components.dropLast().contains(where: manifestTargetTreeNames.contains) else {
        return false
    }
    guard
        filename == "Package.swift"
            || (filename.hasPrefix("Package@swift-") && filename.hasSuffix(".swift"))
    else { return false }
    // The package root's manifest is the manifest by definition. A nested file of
    // that name is one only if it reads as one: a fixture holding just a
    // tools-version line is source, as swift-linter's walker and the Institute
    // source subject treat it, and the manifest rules do not apply to it.
    guard path.split(separator: "/").filter({ $0 != "." }).count > 1 else { return true }
    return Package.Manifest.recognizes(Swift::Array(utf8: text))
}

internal func manifestUnmeasurableShape(_ tree: SourceFileSyntax) -> Swift::String? {
    guard !tree.hasError else {
        return "the manifest does not parse"
    }
    let counter = ManifestPackageInitializerCounter(viewMode: .sourceAccurate)
    counter.walk(tree)
    return counter.count > 1
        ? "expected at most one Package initializer; found \(counter.count)"
        : nil
}

internal final class ManifestPackageInitializerCounter: SyntaxVisitor {
    var count = 0

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Package" {
            count += 1
        }
        return .visitChildren
    }
}

private let manifestTargetTreeNames: Swift::Set<Swift::Substring> = ["Sources", "Plugins"]

@usableFromInline
internal let manifestBareStringDependencyMessage: Swift::String =
    "[bare string dependency]: a target dependency must use a typed "
    + "accessor — `.target(name:)` for a same-package target, "
    + "`.product(name:package:)` for a product — never a bare string. "
    + "SwiftPM resolves a bare string as `.byName`, which binds to "
    + "whatever it resolves first."

private let manifestTargetFactories: Swift::Set<Swift::String> = [
    "target", "testTarget", "executableTarget", "macro", "plugin",
]

internal final class ManifestBareStringDependencyVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var unhandledSourceShape: Swift::String?

    private var fileScopeBindings: [Swift::String: ExprSyntax] = [:]
    private var dependencyAccessorBodies: [Swift::String: ExprSyntax] = [:]

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    internal func collectFileScopeBindings(_ file: SourceFileSyntax) {
        dependencyAccessorBodies = manifestAccessorBodies(
            in: file,
            extendedTypes: ["Target.Dependency", "PackageDescription.Target.Dependency"],
            static: true
        )
        for statement in Lint.Syntax.Conditional.statements(file.statements) {
            guard let variable = statement.item.as(VariableDeclSyntax.self) else { continue }
            for binding in variable.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                    let initializer = binding.initializer?.value
                else { continue }
                fileScopeBindings[pattern.identifier.text] = initializer
            }
        }
    }

    private func resolvedElements(
        of expression: ExprSyntax,
        visited: Swift::Set<Swift::String> = []
    ) -> [ExprSyntax] {
        if let array = expression.as(ArrayExprSyntax.self) {
            return array.elements.map(\.expression)
        }
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            let name = reference.baseName.text
            guard !visited.contains(name), let bound = fileScopeBindings[name] else {
                unhandledSourceShape = "unresolved dependency array reference '\(name)'"
                return []
            }
            return resolvedElements(of: bound, visited: visited.union([name]))
        }
        if let sequence = expression.as(SequenceExprSyntax.self) {
            var result: [ExprSyntax] = []
            for element in sequence.elements where element.as(BinaryOperatorExprSyntax.self) == nil {
                result.append(contentsOf: resolvedElements(of: element, visited: visited))
            }
            return result
        }
        unhandledSourceShape =
            "computed dependency array '\(expression.trimmedDescription)'"
        return []
    }

    private func flaggedPosition(
        of element: ExprSyntax,
        visited: Swift::Set<Swift::String> = []
    ) -> AbsolutePosition? {
        if let literal = element.as(StringLiteralExprSyntax.self) {
            return literal.positionAfterSkippingLeadingTrivia
        }
        if let call = element.as(FunctionCallExprSyntax.self),
            let member = call.calledExpression.as(MemberAccessExprSyntax.self),
            member.declName.baseName.text == "byName"
        {
            return call.positionAfterSkippingLeadingTrivia
        }
        if let reference = element.as(DeclReferenceExprSyntax.self) {
            let name = reference.baseName.text
            guard !visited.contains(name), let bound = fileScopeBindings[name] else {
                unhandledSourceShape = "unresolved target dependency reference '\(name)'"
                return nil
            }
            guard bound.is(StringLiteralExprSyntax.self) else {
                unhandledSourceShape =
                    "computed target dependency '\(bound.trimmedDescription)'"
                return nil
            }
            return reference.positionAfterSkippingLeadingTrivia
        }
        if element.is(MemberAccessExprSyntax.self) {
            let classification = manifestBareStringDependencyClassification(
                element,
                accessorBodies: dependencyAccessorBodies,
                unhandledSourceShape: &unhandledSourceShape
            )
            guard classification.handled else { return nil }
            return classification.isBare ? element.positionAfterSkippingLeadingTrivia : nil
        }
        if let call = element.as(FunctionCallExprSyntax.self),
            let member = call.calledExpression.as(MemberAccessExprSyntax.self),
            ["target", "product", "plugin"].contains(member.declName.baseName.text)
        {
            return nil
        }
        unhandledSourceShape =
            "unhandled target dependency '\(element.trimmedDescription)'"
        return nil
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard
            let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            manifestTargetFactories.contains(member.declName.baseName.text)
        else {
            return .visitChildren
        }
        for argument in node.arguments where argument.label?.text == "dependencies" {
            for element in resolvedElements(of: argument.expression) {
                guard let position = flaggedPosition(of: element) else { continue }
                emit(at: position)
            }
        }
        return .visitChildren
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
                identifier: "bare string dependency",
                message: manifestBareStringDependencyMessage
            )
        )
    }
}

private func manifestBareStringDependencyClassification(
    _ expression: ExprSyntax,
    accessorBodies: [Swift::String: ExprSyntax],
    visited: Swift::Set<Swift::String> = [],
    unhandledSourceShape: inout Swift::String?
) -> (handled: Swift::Bool, isBare: Swift::Bool) {
    if expression.is(StringLiteralExprSyntax.self) {
        return (true, true)
    }

    if let call = expression.as(FunctionCallExprSyntax.self),
        let member = call.calledExpression.as(MemberAccessExprSyntax.self)
    {
        switch member.declName.baseName.text {
        case "byName":
            return (true, true)
        case "target", "product", "plugin":
            return (true, false)
        default:
            break
        }
    }

    if let member = expression.as(MemberAccessExprSyntax.self), member.base == nil {
        let name = member.declName.baseName.text
        guard !visited.contains(name), let body = accessorBodies[name] else {
            unhandledSourceShape =
                unhandledSourceShape ?? "unresolved target dependency accessor '\(name)'"
            return (false, false)
        }
        return manifestBareStringDependencyClassification(
            body,
            accessorBodies: accessorBodies,
            visited: visited.union([name]),
            unhandledSourceShape: &unhandledSourceShape
        )
    }

    unhandledSourceShape =
        unhandledSourceShape
        ?? "unhandled target dependency '\(expression.trimmedDescription)'"
    return (false, false)
}
