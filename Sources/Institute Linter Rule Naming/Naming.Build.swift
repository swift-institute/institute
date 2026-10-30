extension Naming {
    internal enum Build {}
}

extension Naming.Build {
    @usableFromInline
    internal static let methods: Swift::Set<Swift::String> = [
        "buildExpression",
        "buildBlock",
        "buildPartialBlock",
        "buildOptional",
        "buildEither",
        "buildArray",
        "buildLimitedAvailability",
        "buildFinalResult",
    ]
}
