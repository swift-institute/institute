public import Lint

extension Lint.Rule.Bundle {

    public static let framework: [Lint.Rule.Configuration] = [
        .enable(.`framework import`),
        .enable(.`owned api`),
    ]
}
