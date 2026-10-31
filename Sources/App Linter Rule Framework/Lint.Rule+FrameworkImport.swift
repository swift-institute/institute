public import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.Rule {

    /// An Apple-only framework is imported only by the adapter target named for it.
    public static let `framework import` = Lint.Rule(
        id: "framework import",
        default: .warning,
        controls: [
            .init(
                id: "framework import in a core target",
                source: "import PDFKit",
                path: "Sources/Reader/Reader+Extract.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "framework import re-exported",
                source: "@_exported public import Vision",
                path: "Sources/Reader Text/exports.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "framework import of one declaration",
                source: "import struct PDFKit.PDFDocument",
                path: "Sources/Docket Shelf/Placement.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "framework import inside a conditional",
                source: """
                    #if os(macOS)
                    import PDFKit
                    #endif
                    """,
                path: "Sources/Reader/Reader+Extract.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "framework import in its adapter",
                source: "import PDFKit\nimport CoreGraphics",
                path: "Sources/Reader PDFKit/Reader.PDF+PDFKit.swift",
                expectation: .clean
            ),
            .init(
                id: "framework import in its adapter's tests",
                source: "import PDFKit",
                path: "Tests/Reader PDFKit Tests/Reader.PDF Tests.swift",
                expectation: .clean
            ),
            .init(
                id: "framework import in another family's adapter",
                source: "import PDFKit",
                path: "Sources/Affairs PDFKit/Affairs.PDF.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "framework import as a view's companion",
                source: "import SwiftUI\nimport PDFKit",
                path: "Sources/Laurie SwiftUI/Retrieval.View.Preview.swift",
                expectation: .clean
            ),
            .init(
                id: "framework import near miss",
                source: "import PDFKit",
                path: "Sources/Reader PDFKitty/Reader.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "framework import bare filename",
                source: "import PDFKit",
                path: "main.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "framework import portable module",
                source: "import Foundation\nimport Dispatch\nimport Observation",
                path: "Sources/Reader/Reader.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = FrameworkImportVisitor()
            visitor.walk(source.tree)
            return visitor.sites.compactMap { site in
                guard !Lint.Framework.admits(site.module, at: source.path) else { return nil }
                return Lint.Scope.record(
                    at: site.node,
                    in: source,
                    severity: severity,
                    identifier: "framework import",
                    message: `framework import message`(site.module)
                )
            }
        }
    )
}

package func `framework import message`(_ module: Swift::String) -> Swift::String {
    let owners = Lint.Framework.owners[module].map { " whose name opens with " + $0.sorted().joined(separator: " or ") } ?? ""
    return "[framework import]: `\(module)` is Apple-only and is imported outside its adapter. Only a target "
        + "named '… \(module)'\(owners) may import it (or its test target). Fix: move the code into that adapter, "
        + "behind the core interface it implements. This checks the import, not that the adapter implements an "
        + "interface."
}

internal final class FrameworkImportVisitor: SyntaxVisitor {
    struct Site {
        let node: Syntax
        let module: Swift::String
    }

    var sites: [Site] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        if let module = node.path.first?.name.text { sites.append(Site(node: Syntax(node), module: module)) }
        return .skipChildren
    }
}
