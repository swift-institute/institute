import Lint
import Linter_Rules_Test_Support
import Testing

@testable import App_Linter_Rule_SwiftUI

@Suite
struct `SwiftUI Tests` {
    @Suite struct Scope {}
    @Suite struct `With Animation` {}
    @Suite struct `Animation Modifier` {}
    @Suite struct `State Identity` {}
    @Suite struct `View State` {}
    @Suite struct `View Logic` {}
    @Suite struct Exemption {}
    @Suite struct Integration {}
}

extension `SwiftUI Tests` {
    static let rules: [Lint.Rule] = [
        .`with animation`, .`animation modifier`, .`state identity`, .`view state`, .`view logic`,
    ]

    static func findings(
        _ rule: Lint.Rule,
        _ source: Swift::String,
        file: Swift::String = "Sources/Laurie SwiftUI/Screen.swift"
    ) -> [Diagnostic.Record] {
        rule.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
    }

    static func view(_ body: Swift::String) -> Swift::String {
        """
        struct Screen: View {
          let store: StoreOf<Feature>
          var body: some View {
            \(body)
          }
        }
        """
    }
}

extension `SwiftUI Tests`.Scope {
    @Test
    func `non-view type does not fire`() {
        let source = """
            struct Model {
              func run() { withAnimation { }; _ = items.filter { $0 }; _ = Date() }
            }
            """
        #expect(`SwiftUI Tests`.findings(.`with animation`, source).isEmpty)
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).isEmpty)
    }

    @Test
    func `qualified SwiftUI.View conformer fires`() {
        let source = """
            extension Laurie { struct View: SwiftUI.View { var body: some SwiftUI.View { Text("A").onAppear { } } } }
            """
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).count == 1)
    }

    @Test
    func `a type made a view by TCA26's View macro fires, with its extensions`() {
        let source = """
            extension Laurie {
              @View(Laurie.self)
              struct View { @State private var sweep = false; let close: () -> Void }
            }
            extension Laurie.View { var body: some SwiftUI.View { Text("A").onAppear { } } }
            """
        #expect(`SwiftUI Tests`.findings(.`view state`, source).count == 2)
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).count == 1)
    }

    @Test
    func `a type under another macro is not a view`() {
        let source = """
            @Feature struct Row { @State var expanded = false; func run() { _ = items.filter { $0 } } }
            """
        #expect(`SwiftUI Tests`.findings(.`view state`, source).isEmpty)
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).isEmpty)
    }

    @Test
    func `extension of a view in the same file fires`() {
        let source = """
            extension Laurie { struct Row: View { var body: some View { header } } }
            extension Laurie.Row { var header: some View { Text(Date().description) } }
            """
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).count == 1)
    }

    @Test
    func `extension adding View conformance fires`() {
        let source = """
            extension Row: View { var body: some View { Text("A").task { } } }
            """
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).count == 1)
    }

    @Test
    func `nested non-view type inside a view does not fire`() {
        let source = """
            struct Screen: View {
              var body: some View { Text("A") }
              enum Layout { static func sorted(_ x: [Int]) -> [Int] { x.sorted() } }
            }
            """
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).isEmpty)
    }

    @Test
    func `extension of a view declared in another file fires`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Sources/Laurie SwiftUI/Laurie.Row.swift": "extension Laurie { struct Row: View { var body: some View { header } } }",
            "Sources/Laurie SwiftUI/Laurie.Row+Header.swift": "extension Laurie.Row { var header: some View { Text(\"\").onAppear { } } }",
            "Sources/Laurie SwiftUI/Laurie.Model.swift": "extension Laurie.Model { func f() { _ = xs.map { $0 } } }",
        ])
        let header = Lint.Rule.`view logic`.observe(
            fixture.parsed("Sources/Laurie SwiftUI/Laurie.Row+Header.swift"),
            .warning
        ).findings
        #expect(header.count == 1)
        let model = Lint.Rule.`view logic`.observe(
            fixture.parsed("Sources/Laurie SwiftUI/Laurie.Model.swift"),
            .warning
        ).findings
        #expect(model.isEmpty)
    }

    @Test
    func `bare filename view still fires`() {
        let source = `SwiftUI Tests`.view("Button(\"A\") { withAnimation { } }")
        #expect(`SwiftUI Tests`.findings(.`with animation`, source, file: "Screen.swift").count == 1)
    }
}

extension `SwiftUI Tests`.`With Animation` {
    @Test
    func `withAnimation and SwiftUI.withAnimation fire`() {
        let source = `SwiftUI Tests`.view(
            "Button(\"A\") { withAnimation(.default) { flag.toggle() }; SwiftUI.withAnimation { } }"
        )
        #expect(`SwiftUI Tests`.findings(.`with animation`, source).count == 2)
    }

    @Test
    func `withAnimation around store sends is the coenttb-app A3 form and does not fire`() {
        let source = `SwiftUI Tests`.view(
            """
            Button("A") { withAnimation { store.send(.selectAllButtonTapped) } }
                Button("B") { withAnimation(.snappy) { self.store.send(.a); store.send(.b) } }
                Button("C") { SwiftUI.withAnimation(.default, { store.send(.c) }) }
            """
        )
        #expect(`SwiftUI Tests`.findings(.`with animation`, source).isEmpty)
    }

    @Test
    func `near miss: withAnimation around anything besides store sends fires`() {
        let source = `SwiftUI Tests`.view(
            """
            Button("A") { withAnimation { store.send(.a); flag.toggle() } }
                Button("B") { withAnimation { model.send(.b) } }
                Button("C") { withAnimation { _ = store.send(.c) } }
                Button("D") { withAnimation { store.state.value = 1 } }
            """
        )
        #expect(`SwiftUI Tests`.findings(.`with animation`, source).count == 4)
    }

    @Test
    func `withTransaction does not fire`() {
        let source = `SwiftUI Tests`.view("Button(\"A\") { withTransaction(t) { } }")
        #expect(`SwiftUI Tests`.findings(.`with animation`, source).isEmpty)
    }
}

extension `SwiftUI Tests`.`Animation Modifier` {
    @Test
    func `unscoped animation and animated non-store bindings fire`() {
        let source = `SwiftUI Tests`.view(
            """
            Text("A")
                  .animation(.default, value: store.count)
                  .animation(.spring)
                Toggle("B", isOn: $store.flag.animation())
                Toggle("C", isOn: $flag.animation(.easeIn))
            """
        )
        #expect(`SwiftUI Tests`.findings(.`animation modifier`, source).count == 2)
    }

    @Test
    func `the coenttb-app A3 forms do not fire`() {
        let source = `SwiftUI Tests`.view(
            """
            Text("A")
                  .animation(.default, value: store.isSelecting)
                Toggle("B", isOn: $store.flag.animation())
                Toggle("C", isOn: $store.filter.isActive.animation(.snappy))
                TextField("D", text: self.$store.query.animation())
            """
        )
        #expect(`SwiftUI Tests`.findings(.`animation modifier`, source).isEmpty)
    }

    @Test
    func `near miss: a binding not rooted at the store still fires`() {
        let source = `SwiftUI Tests`.view(
            """
            Toggle("A", isOn: $model.flag.animation())
                Toggle("B", isOn: $storeCopy.flag.animation())
                Toggle("C", isOn: other.$store.flag.animation())
            """
        )
        #expect(`SwiftUI Tests`.findings(.`animation modifier`, source).count == 3)
    }

    @Test
    func `allowed transitions and closure form do not fire`() {
        let source = `SwiftUI Tests`.view(
            """
            Text("A")
                  .transition(.opacity)
                  .contentTransition(.numericText())
                  .symbolEffect(.bounce, value: store.count)
                  .animation(.default) { $0.opacity(1) }
                Text(store.title.animation)
            """
        )
        #expect(`SwiftUI Tests`.findings(.`animation modifier`, source).isEmpty)
    }
}

extension `SwiftUI Tests`.`State Identity` {
    @Test
    func `state-driven identity fires`() {
        let source = `SwiftUI Tests`.view(
            "Text(\"A\").id(store.document).id(selection).id(\"row-\\(store.id)\")"
        )
        #expect(`SwiftUI Tests`.findings(.`state identity`, source).count == 3)
    }

    @Test
    func `literal and static identity does not fire`() {
        let source = `SwiftUI Tests`.view(
            "Text(\"A\").id(\"header\").id(1).id(-1).id(true).id(Anchor.top).id(Self.anchor).id(.bottom).id(Laurie.Anchor.top)"
        )
        #expect(`SwiftUI Tests`.findings(.`state identity`, source).isEmpty)
    }

    @Test
    func `ForEach id label does not fire`() {
        let source = `SwiftUI Tests`.view("ForEach(store.rows, id: \\.id) { Text($0.title) }")
        #expect(`SwiftUI Tests`.findings(.`state identity`, source).isEmpty)
    }
}

extension `SwiftUI Tests`.`View State` {
    @Test
    func `state wrappers fire`() {
        let source = """
            struct Screen: View {
              @State private var expanded = false
              @StateObject var model = Model()
              @ObservedObject var other: Other
              @AppStorage("k") var stored = 0
              @SceneStorage("s") var scene = ""
              @SwiftUI.State var qualified = 1
              var body: some View { Text("A") }
            }
            """
        #expect(`SwiftUI Tests`.findings(.`view state`, source).count == 6)
    }

    @Test
    func `stored closures fire and computed ones do not`() {
        let source = """
            struct Screen: View {
              let onTap: () -> Void
              var onClose: (@MainActor @Sendable (Int) -> Void)?
              var action: (() -> Void)! { didSet { } }
              var computed: () -> Void { { } }
              static let shared: () -> Void = { }
              var body: some View { Text("A") }
            }
            """
        #expect(`SwiftUI Tests`.findings(.`view state`, source).count == 3)
    }

    @Test
    func `observable class properties fire`() {
        let source = """
            @Observable final class Model {}
            struct Screen: View {
              let model: Model
              var optional: Model?
              let made = Model()
              var body: some View { Text("A") }
            }
            """
        #expect(`SwiftUI Tests`.findings(.`view state`, source).count == 3)
    }

    @Test
    func `allowed properties do not fire`() {
        let source = """
            struct Screen: View {
              let store: StoreOf<Feature>
              @Bindable var bound: StoreOf<Feature>
              @Namespace var namespace
              @FocusState var focused: Bool
              @ScaledMetric var size = 12.0
              @GestureState var drag = CGSize.zero
              @Environment(\\.dismiss) var dismiss
              let title: String
              var body: some View { Text("A") }
            }
            """
        #expect(`SwiftUI Tests`.findings(.`view state`, source).isEmpty)
    }
}

extension `SwiftUI Tests`.`View Logic` {
    @Test(arguments: [
        "xs.filter { $0 }", "xs.sorted()", "xs.sort()", "xs.reduce(0, +)", "xs.map(\\.id)",
        "xs.compactMap { $0 }", "xs.flatMap { $0 }", "xs.first(where: { $0 })", "xs.first { $0 }",
        "xs.last(where: { $0 })", "xs.contains(where: { $0 })", "xs.min()", "xs.max(by: <)",
        "xs.allSatisfy { $0 }", "Set(xs)", "Set<Int>()", "Dictionary(grouping: xs) { $0 }",
        "[Int: Int]()", "Task { }", "Task.detached { }", "Date()", "Date.now", "UUID()",
        "UserDefaults.standard", "FileManager.default", "Store(initialState: .init()) { Feature() }",
        "store.modify { _ in }",
    ])
    func `each logic form fires once`(expression: Swift::String) {
        let source = `SwiftUI Tests`.view("let _ = \(expression)")
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).count == 1, "\(expression)")
    }

    @Test(arguments: [
        ".task { }", ".task(id: store.id) { }", ".onAppear { }", ".onDisappear { }",
        ".onChange(of: store.x) { }", ".onReceive(publisher) { _ in }",
    ])
    func `each lifecycle modifier fires once`(modifier: Swift::String) {
        let source = `SwiftUI Tests`.view("Text(\"A\")\(modifier)")
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).count == 1, "\(modifier)")
    }

    @Test
    func `map passed to ForEach is not exempt`() {
        let source = `SwiftUI Tests`.view("ForEach(store.rows.map(\\.title), id: \\.self) { Text($0) }")
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).count == 1)
    }

    @Test
    func `store reads, sends and formatting do not fire`() {
        let source = `SwiftUI Tests`.view(
            """
            ForEach(store.rows) { row in Text(row.date, format: .dateTime) }
                Button("Done") { store.send(.doneTapped) }
                Text(store.first)
                Text(store.items.contains(store.item) ? "Y" : "N")
                Text(Date(timeIntervalSince1970: 0), style: .date)
            """
        )
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).isEmpty)
    }
}

extension `SwiftUI Tests`.Exemption {
    @Test
    func `representables and their coordinator are exempt`() {
        let source = """
            struct Web: UIViewRepresentable {
              @State var loaded = false
              func makeUIView(context: Context) -> WKWebView { withAnimation { }; return WKWebView() }
              final class Coordinator { func f() { _ = xs.map { $0 }; _ = Date() } }
            }
            struct Mac: SwiftUI.NSViewRepresentable, View {
              func makeNSView(context: Context) -> NSView { _ = xs.filter { $0 }; return NSView() }
            }
            extension Web { final class Delegate { func f() { _ = xs.sorted() } } }
            """
        for rule in `SwiftUI Tests`.rules {
            #expect(`SwiftUI Tests`.findings(rule, source).isEmpty, "\(rule.id)")
        }
    }

    @Test
    func `near miss: view controller representable is not exempt`() {
        let source = """
            struct Picker: UIViewControllerRepresentable, View {
              func make() { _ = xs.map { $0 } }
            }
            """
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).count == 1)
    }

    @Test
    func `near miss: a view nested beside a representable still fires`() {
        let source = """
            struct Web: UIViewRepresentable { }
            struct Screen: View { var body: some View { Text("A").onAppear { } } }
            """
        #expect(`SwiftUI Tests`.findings(.`view logic`, source).count == 1)
    }
}

extension `SwiftUI Tests`.Integration {
    @Test
    func `controls hold for every rule`() {
        for rule in `SwiftUI Tests`.rules {
            let outcomes = rule.outcomes()
            #expect(outcomes.contains { $0.expected > 0 }, "\(rule.id)")
            for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
        }
    }

    @Test
    func `messages state what they check and the fix`() {
        let source = `SwiftUI Tests`.view("Button(\"A\") { withAnimation { } }")
        let message = `SwiftUI Tests`.findings(.`with animation`, source).first?.message ?? ""
        #expect(message.contains("This rule checks for `withAnimation` calls"))
        #expect(message.contains("Fix:"))
    }
}
