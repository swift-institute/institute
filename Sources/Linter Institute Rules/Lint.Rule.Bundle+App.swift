public import Lint
internal import App_Linter_Rule_Feature
internal import App_Linter_Rule_Framework
internal import App_Linter_Rule_SwiftUI
internal import Linter_Rule_SwiftUI

extension Lint.Rule.Bundle {
    /// An app and the packages under it: the institute bundle, the rules that keep logic out of views and
    /// features, and the rules that keep each Apple framework inside its adapter. A view that holds state or logic is
    /// an error (coenttb/kees#42, step 9).
    public static let app: [Lint.Rule.Configuration] =
        Lint.Rule.Bundle.institute
        + Lint.Rule.Bundle.framework
        + Lint.Rule.Bundle.feature
        + [
            .enable(.`with animation`),
            .enable(.`animation modifier`),
            .enable(.`state identity`),
            .enable(.`toolbar hidden`),
            .enable(.`view state`, severity: .error),
            .enable(.`view logic`, severity: .error),
        ]
}
