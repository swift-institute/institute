public import Institute_Model
internal import Source_Profile

extension Institute.Source.Policy {
    internal static let swiftFormatRules: [(Swift.String, Swift.Bool)] = [
        ("AlwaysUseLowerCamelCase", false),
        ("AmbiguousTrailingClosureOverload", true),
        ("DoNotUseSemicolons", true),
        ("DontRepeatTypeInStaticProperties", true),
        ("FileScopedDeclarationPrivacy", true),
        ("FullyIndirectEnum", true),
        ("GroupNumericLiterals", true),
        ("IdentifiersMustBeASCII", true),
        ("NeverForceUnwrap", true),
        ("NeverUseForceTry", true),
        ("NeverUseImplicitlyUnwrappedOptionals", true),
        ("NoAccessLevelOnExtensionDeclaration", true),
        ("NoBlockComments", true),
        ("NoCasesWithOnlyFallthrough", true),
        ("NoEmptyTrailingClosureParentheses", true),
        ("NoLabelsInCasePatterns", true),
        ("NoLeadingUnderscores", false),
        ("NoParensAroundConditions", true),
        ("NoVoidReturnOnFunctionSignature", true),
        ("OneCasePerLine", true),
        ("OneVariableDeclarationPerLine", true),
        ("OnlyOneTrailingClosureArgument", true),
        ("OrderedImports", true),
        ("ReturnVoidInsteadOfEmptyTuple", true),
        ("UseEarlyExits", true),
        ("UseLetInEveryBoundCaseVariable", true),
        ("UseShorthandTypeNames", true),
        ("UseSingleLinePropertyGetter", true),
        ("UseSynthesizedInitializer", false),
        ("UseTripleSlashForDocumentationComments", true),
        ("UseWhereClausesInForLoops", false),
    ]

    internal static let swiftFormatCorrectableRules: Swift.Set<Swift.String> = [
        "DoNotUseSemicolons",
        "FileScopedDeclarationPrivacy",
        "FullyIndirectEnum",
        "GroupNumericLiterals",
        "NoAccessLevelOnExtensionDeclaration",
        "NoCasesWithOnlyFallthrough",
        "NoEmptyTrailingClosureParentheses",
        "NoLabelsInCasePatterns",
        "NoParensAroundConditions",
        "NoVoidReturnOnFunctionSignature",
        "OneCasePerLine",
        "OneVariableDeclarationPerLine",
        "OrderedImports",
        "ReturnVoidInsteadOfEmptyTuple",
        "UseLetInEveryBoundCaseVariable",
        "UseShorthandTypeNames",
        "UseSingleLinePropertyGetter",
    ]

    internal static let swiftFormatConfiguration: Swift.String =
        configuration(rules: swiftFormatRules)

    internal static let swiftFormatRepairConfiguration: Swift.String =
        configuration(
            rules: swiftFormatRules.map { rule in
                (rule.0, rule.1 && swiftFormatCorrectableRules.contains(rule.0))
            }
        )

    private static func configuration(
        rules: [(Swift.String, Swift.Bool)]
    ) -> Swift.String {
        let document = JSON.object([
            ("version", 1),
            ("lineLength", 200),
            ("indentation", JSON.object([("spaces", 4)])),
            ("maximumBlankLines", 1),
            ("respectsExistingLineBreaks", true),
            ("lineBreakBeforeControlFlowKeywords", false),
            ("lineBreakBeforeEachArgument", true),
            ("lineBreakBeforeEachGenericRequirement", true),
            ("prioritizeKeepingFunctionOutputTogether", true),
            ("indentConditionalCompilationBlocks", true),
            ("indentSwitchCaseLabels", false),
            ("spacesAroundRangeFormationOperators", false),
            ("fileScopedDeclarationPrivacy", JSON.object([("accessLevel", "private")])),
            ("rules", JSON.object(rules.map { ($0.0, JSON(booleanLiteral: $0.1)) })),
        ])
        return document.serialize(pretty: true) + "\n"
    }
}
