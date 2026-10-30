internal import SwiftSyntax

internal final class ManifestPackagePolicyInspection: SyntaxVisitor {

    private static let requiredSettings: [Swift::String] = [
        ".strictMemorySafety()",
        ".enableUpcomingFeature(\"ExistentialAny\")",
        ".enableUpcomingFeature(\"InternalImportsByDefault\")",
        ".enableUpcomingFeature(\"MemberImportVisibility\")",
        ".enableUpcomingFeature(\"NonisolatedNonsendingByDefault\")",
        ".enableExperimentalFeature(\"Lifetimes\")",
        ".enableUpcomingFeature(\"InferIsolatedConformances\")",
    ]

    private let sourceText: Swift::String
    private let isL1: Swift::Bool
    private var packageCalls = 0
    private var languageModeArgumentSeen = false
    private var languageModeValid = false
    private var languageModeUnhandled = false
    private var ordinaryTargetCount = 0
    private var recognizedSettingsLoop: Swift::String?
    private var wrongApplePlatforms: Swift::Set<Swift::String> = []
    private var platformShapeUnhandled = false
    private var l1MacroTarget = false
    private let mentionsSwiftSettings: Swift::Bool

    internal init(_ tree: SourceFileSyntax, filePath: Swift::String) {
        self.sourceText = tree.description
        self.isL1 = filePath.contains("/swift-atoms/") || filePath.contains("/swift-molecules/")
        self.mentionsSwiftSettings = tree.tokens(viewMode: .sourceAccurate).contains { $0.text == "swiftSettings" }
        super.init(viewMode: .sourceAccurate)
        walk(tree)
    }

    internal var toolsVersionIs64: Swift::Bool {
        guard let first = sourceText.split(separator: "\n", omittingEmptySubsequences: false).first
        else { return false }
        return first == "// swift-tools-version: 6.4"
    }

    internal var languageModeIsV6: Swift::Bool {
        languageModeArgumentSeen && languageModeValid
    }

    internal var applePlatformsNotAtV27: Swift::Set<Swift::String> {
        wrongApplePlatforms
    }

    internal var hasOrdinaryTargets: Swift::Bool { ordinaryTargetCount > 0 }

    internal var hasL1MacroTarget: Swift::Bool { isL1 && l1MacroTarget }

    internal var missingOrdinaryTargetSettings: [Swift::String] {
        guard let loop = recognizedSettingsLoop else { return Self.requiredSettings }
        return Self.requiredSettings.filter { !loop.contains($0) }
    }

    internal var unmeasuredReason: Swift::String? {
        if packageCalls != 1 {
            return "expected exactly one Package initializer; found \(packageCalls)"
        }
        if languageModeUnhandled {
            return "computed or noncanonical swiftLanguageModes"
        }
        if platformShapeUnhandled {
            return "computed or noncanonical Apple platform declaration"
        }
        if ordinaryTargetCount > 0 && recognizedSettingsLoop == nil && mentionsSwiftSettings {
            return "ordinary target settings are not applied by a recognized package.targets loop"
        }
        return nil
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let reference = node.calledExpression.as(DeclReferenceExprSyntax.self),
            reference.baseName.text == "Package"
        {
            packageCalls += 1
            inspectPackage(node)
            return .visitChildren
        }

        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else {
            return .visitChildren
        }
        let name = member.declName.baseName.text
        if ["target", "testTarget", "executableTarget"].contains(name),
            !isNestedInsideDependenciesArgument(Syntax(node))
        {
            ordinaryTargetCount += 1
        }
        if name == "macro", !isNestedInsideDependenciesArgument(Syntax(node)) {
            l1MacroTarget = true
        }
        return .visitChildren
    }

    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        if node.pattern.trimmedDescription == "target",
            node.sequence.trimmedDescription == "package.targets",
            node.whereClause.map({ Self.excludesOnlyNonSourceTargets($0.condition) }) ?? true,
            node.body.statements.contains(where: { Self.compact($0).hasPrefix("target.swiftSettings=") })
        {
            recognizedSettingsLoop = Self.compact(node.body)
        }
        return .visitChildren
    }

    private func inspectPackage(_ node: FunctionCallExprSyntax) {
        for argument in node.arguments {
            switch argument.label?.text {
            case "swiftLanguageModes": inspectLanguageModes(argument.expression)
            case "platforms": inspectPlatforms(argument.expression)
            default: continue
            }
        }
    }

    private func inspectLanguageModes(_ expression: ExprSyntax) {
        languageModeArgumentSeen = true
        guard let array = expression.as(ArrayExprSyntax.self) else {
            languageModeUnhandled = true
            return
        }
        let modes = array.elements.compactMap {
            $0.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
        }
        guard modes.count == array.elements.count else {
            languageModeUnhandled = true
            return
        }
        languageModeValid = modes == ["v6"]
    }

    private func inspectPlatforms(_ expression: ExprSyntax) {
        guard let array = expression.as(ArrayExprSyntax.self) else {
            platformShapeUnhandled = true
            return
        }
        let apple = Swift::Set(["macOS", "iOS", "tvOS", "watchOS", "visionOS"])
        for element in array.elements {
            guard let call = element.expression.as(FunctionCallExprSyntax.self),
                let member = call.calledExpression.as(MemberAccessExprSyntax.self)
            else {
                platformShapeUnhandled = true
                continue
            }
            let name = member.declName.baseName.text
            guard apple.contains(name) else { continue }
            guard call.arguments.count == 1,
                let version = call.arguments.first?.expression.as(MemberAccessExprSyntax.self)
            else {
                platformShapeUnhandled = true
                continue
            }
            if version.declName.baseName.text != "v27" {
                wrongApplePlatforms.insert(name)
            }
        }
    }

    private func isNestedInsideDependenciesArgument(_ node: Syntax) -> Swift::Bool {
        var current = node.parent
        while let candidate = current {
            if let labeled = candidate.as(LabeledExprSyntax.self),
                labeled.label?.text == "dependencies"
            {
                return true
            }
            current = candidate.parent
        }
        return false
    }

    private static let nonSourceTargetTypes: Swift::Set<Swift::String> = ["system", "binary", "plugin", "macro"]

    private static func excludesOnlyNonSourceTargets(_ condition: ExprSyntax) -> Swift::Bool {
        guard let negation = condition.as(PrefixOperatorExprSyntax.self),
            negation.operator.text == "!",
            let call = negation.expression.as(FunctionCallExprSyntax.self),
            let member = call.calledExpression.as(MemberAccessExprSyntax.self),
            member.declName.baseName.text == "contains",
            let array = member.base?.as(ArrayExprSyntax.self),
            call.arguments.count == 1,
            call.arguments.first?.expression.trimmedDescription == "target.type"
        else { return false }
        let excluded = array.elements.compactMap {
            $0.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
        }
        return excluded.count == array.elements.count && excluded.allSatisfy(nonSourceTargetTypes.contains)
    }

    private static func compact(_ syntax: some SyntaxProtocol) -> Swift::String {
        syntax.tokens(viewMode: .sourceAccurate).map(\.text).joined()
    }
}
