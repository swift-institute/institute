public import Lint

extension Lint.Rule.Bundle {

    public static let feature: [Lint.Rule.Configuration] = [
        .enable(.`feature user defaults`),
        .enable(.`feature with animation`),
    ]
}
