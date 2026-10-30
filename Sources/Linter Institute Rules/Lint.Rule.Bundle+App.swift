public import Lint

extension Lint.Rule.Bundle {
    /// An app and the packages under it: the institute bundle, the rules that keep logic out of views and
    /// features, and the rules that keep each Apple framework inside its adapter.
    public static let app: [Lint.Rule.Configuration] = Lint.Rule.Bundle.institute
}
