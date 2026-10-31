public import Lint
internal import Linter_Rule_Scope
internal import Linter_Rule_SwiftUI
internal import SwiftSyntax

extension Lint.Rule {

    public static let `with animation` = Lint.Rule(
        id: "with animation",
        default: .warning,
        controls: [
            .init(
                id: "with animation in view",
                source: """
                    struct Row: View {
                      let store: StoreOf<Feature>
                      var body: some View {
                        Button("Flag") { withAnimation { flagged.toggle() } }
                      }
                    }
                    """,
                path: "Controls/WithAnimation.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "with animation around a store send",
                source: """
                    struct Row: View {
                      let store: StoreOf<Feature>
                      var body: some View {
                        Button("Select All") { withAnimation { store.send(.selectAllButtonTapped) } }
                      }
                    }
                    """,
                path: "Controls/WithAnimationSend.swift",
                expectation: .clean
            ),
            .init(
                id: "with animation outside view",
                source: """
                    struct Model {
                      func run() { withAnimation { } }
                    }
                    """,
                path: "Controls/WithAnimationModel.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.SwiftUI.observe(
            .withAnimation,
            identifier: "with animation",
            message: "This rule checks for `withAnimation` calls \(Lint.SwiftUI.scope) whose body is "
                + "anything other than `store.send(...)` calls. `withAnimation { store.send(.case) }` is how "
                + "a button animates state that never touches the database (coenttb-app A3); whether the "
                + "action writes the database (A2) is not checked. Fix: animate only store sends, and let a "
                + "change that comes from the database animate through the feature's "
                + "`Observing(...).animation()`."
        )
    )

    public static let `animation modifier` = Lint.Rule(
        id: "animation modifier",
        default: .warning,
        controls: [
            .init(
                id: "animation modifier unscoped and non-store binding",
                source: """
                    struct Row: View {
                      @Bindable var store: StoreOf<Feature>
                      var body: some View {
                        Toggle("Flag", isOn: $model.flagged.animation())
                          .animation(.default)
                      }
                    }
                    """,
                path: "Controls/AnimationModifier.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "animation modifier value and store binding",
                source: """
                    struct Row: View {
                      @Bindable var store: StoreOf<Feature>
                      var body: some View {
                        Toggle("Flag", isOn: $store.flagged.animation())
                          .animation(.default, value: store.flagged)
                      }
                    }
                    """,
                path: "Controls/AnimationModifierScoped.swift",
                expectation: .clean
            ),
            .init(
                id: "animation modifier transition",
                source: """
                    struct Row: View {
                      var body: some View { Text("A").transition(.opacity) }
                    }
                    """,
                path: "Controls/AnimationModifierTransition.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.SwiftUI.observe(
            .animationModifier,
            identifier: "animation modifier",
            message: "This rule checks for the unscoped `.animation(_:)` and for `Binding.animation(_:)` "
                + "on a binding not rooted at `$store` \(Lint.SwiftUI.scope). The coenttb-app A3 forms, "
                + "`$store.x.animation()` and `.animation(_:value:)`, are admitted; whether the state "
                + "they animate writes the database (A2) is not checked. Fix: scope the animation with "
                + "`.animation(_:value:)` on the subtree whose look depends on the value, or animate the "
                + "store binding."
        )
    )

    public static let `state identity` = Lint.Rule(
        id: "state identity",
        default: .warning,
        controls: [
            .init(
                id: "state identity driven by state",
                source: """
                    struct Detail: View {
                      let store: StoreOf<Feature>
                      var body: some View { Text(store.title).id(store.document) }
                    }
                    """,
                path: "Controls/StateIdentity.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "state identity static member",
                source: """
                    struct Detail: View {
                      var body: some View { Text("A").id(Anchor.top).id("header").id(.bottom) }
                    }
                    """,
                path: "Controls/StateIdentityStatic.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.SwiftUI.observe(
            .stateIdentity,
            identifier: "state identity",
            message: "This rule checks `.id(_:)` whose argument is neither a literal nor a static "
                + "member, \(Lint.SwiftUI.scope). Identity driven by state discards the view's identity on "
                + "every change, so rows cannot move and transitions replay. Fix: drop the `.id`, or use a "
                + "literal or static member; let `ForEach` identity follow each row's own `id`."
        )
    )

    public static let `view state` = Lint.Rule(
        id: "view state",
        default: .warning,
        controls: [
            .init(
                id: "view state wrapper and closure",
                source: """
                    struct Row: View {
                      @State var expanded = false
                      let onTap: () -> Void
                      var body: some View { Text("A") }
                    }
                    """,
                path: "Controls/ViewState.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "view state allowed properties",
                source: """
                    struct Row: View {
                      @Bindable var store: StoreOf<Feature>
                      @Namespace var namespace
                      @FocusState var focused: Bool
                      var body: some View { Text("A") }
                    }
                    """,
                path: "Controls/ViewStateAllowed.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let message =
                "This rule checks view properties declared with `@State`, `@StateObject`, "
                + "`@ObservedObject`, `@AppStorage` or `@SceneStorage`, properties whose type is an "
                + "`@Observable` class declared in this package, and stored properties of function type, "
                + "\(Lint.SwiftUI.scope). A view holds no state; the one exception is the hover flag of "
                + "`\(Lint.SwiftUI.Hover.modifiers.sorted().joined(separator: "`, `"))` (coenttb-app S3). Fix: move "
                + "the state into the feature's `State` and read it through `store`; replace a stored closure with "
                + "`store.send(.case)`; anything persisted lives in SQLite."
            let visitor = Lint.SwiftUI.Visitor(index: Lint.Scope.Index.of(source))
            visitor.walk(source.tree)
            return visitor.hits
                .filter { $0.kind == .viewState && !Lint.SwiftUI.Hover.allows($0.node) }
                .map { hit in
                    Lint.Scope.record(
                        at: hit.node,
                        in: source,
                        severity: severity,
                        identifier: "view state",
                        message: "[view state]: \(hit.detail). \(message)"
                    )
                }
        }
    )

    public static let `view logic` = Lint.Rule(
        id: "view logic",
        default: .warning,
        controls: [
            .init(
                id: "view logic algorithm and lifecycle",
                source: """
                    struct List: View {
                      let store: StoreOf<Feature>
                      var body: some View {
                        ForEach(store.rows.filter(\\.visible)) { Text($0.title) }
                          .onAppear { store.send(.appeared) }
                      }
                    }
                    """,
                path: "Controls/ViewLogic.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "view logic store reads",
                source: """
                    struct List: View {
                      let store: StoreOf<Feature>
                      var body: some View {
                        ForEach(store.rows) { row in Text(row.title) }
                        Button("Done") { store.send(.doneTapped) }
                      }
                    }
                    """,
                path: "Controls/ViewLogicStore.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.SwiftUI.observe(
            .viewLogic,
            identifier: "view logic",
            message: "This rule checks calls to filter, sorted, sort, reduce, map, compactMap, flatMap, "
                + "first(where:), last(where:), contains(where:), min, max and allSatisfy (including "
                + "`.map` passed to `ForEach`); Set and Dictionary construction; `Task`; the `.task`, "
                + "`.onAppear`, `.onDisappear`, `.onChange` and `.onReceive` modifiers; `Date()`, "
                + "`Date.now`, `UUID()`, `UserDefaults` and `FileManager`; `Store(` initialisation; and "
                + "`store.modify` — \(Lint.SwiftUI.scope). Fix: compute it in SQL (a `@Selection` with "
                + "exactly the columns the row shows) or in the feature, and have the view read `store` "
                + "members and send actions."
        )
    )
}
