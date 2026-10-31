public import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.Rule {

    /// Foundation's file and system calls, and PDFKit's documents, are reached only from their owner.
    public static let `owned api` = Lint.Rule(
        id: "owned api",
        default: .warning,
        controls: [
            .init(
                id: "owned api file manager",
                source: "let files = FileManager.default",
                path: "Sources/Affairs SQLite/Originals.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "owned api qualified",
                source: "try Foundation.FileManager.default.removeItem(at: url)",
                path: "Sources/Affairs SQLite/Originals.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "owned api security scope",
                source: "let scoped = url.startAccessingSecurityScopedResource()",
                path: "Sources/Affairs SQLite/Originals.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "owned api power",
                source: "let hot = ProcessInfo.processInfo.thermalState == .serious",
                path: "Sources/Affairs Reading/Processing.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "owned api reading a file",
                source: "let bytes = try Data(contentsOf: url)",
                path: "Sources/Docket Reading/Reading.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "owned api pdf document",
                source: "let document = PDFDocument(url: url)",
                path: "Sources/Docket Shelf/Placement.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "owned api type alias",
                source: "typealias Files = FileManager",
                path: "Sources/Affairs/Files.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "owned api in its owner",
                source: "let files = FileManager.default\nlet scoped = url.startAccessingSecurityScopedResource()",
                path: "Sources/File System Foundation Integration/File.Bookmark.swift",
                expectation: .clean
            ),
            .init(
                id: "owned api power in its owner",
                source: "let hot = ProcessInfo.processInfo.thermalState == .serious",
                path: "Sources/Reader Darwin/Reader.Queue.Power+Darwin.swift",
                expectation: .clean
            ),
            .init(
                id: "owned api pdf document in its owner",
                source: "let document = PDFDocument(data: data)",
                path: "Sources/Reader PDFKit/Reader.PDF+PDFKit.swift",
                expectation: .clean
            ),
            .init(
                id: "owned api in a comment or string",
                source: "// FileManager is not used here\nlet name = \"FileManager\"",
                path: "Sources/Affairs/Notes.swift",
                expectation: .clean
            ),
            .init(
                id: "owned api near miss",
                source: "let manager = File.Manager()\nlet bytes = try Data(count: 4)",
                path: "Sources/Affairs/Files.swift",
                expectation: .clean
            ),
            .init(
                id: "owned api in tests",
                source: "let files = FileManager.default",
                path: "Tests/Affairs Tests/Originals Tests.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard !Lint.Scope.Target.isTest(source.path) else { return [] }
            let target = Lint.Scope.Target.name(of: source.path)
            let visitor = OwnedAPIVisitor()
            visitor.walk(source.tree)
            return visitor.sites.compactMap { site in
                guard !Lint.Framework.API.owns(target, site.name) else { return nil }
                return Lint.Scope.record(
                    at: site.node,
                    in: source,
                    severity: severity,
                    identifier: "owned api",
                    message: `owned api message`(site.name)
                )
            }
        }
    )
}

package func `owned api message`(_ name: Swift::String) -> Swift::String {
    let owner = Lint.Framework.API.owners[name] ?? ""
    let place = owner.isEmpty ? "No target may use it; use swift-json." : "Only a target named '…\(owner)' may."
    return "[owned api]: `\(name)` is reached outside its owner. \(place) Fix: call the owner's API "
        + "(swift-file-system, the core's interfaces) instead. Uses through a typealias are not tracked."
}

internal final class OwnedAPIVisitor: SyntaxVisitor {
    struct Site {
        let node: Syntax
        let name: Swift::String
    }

    var sites: [Site] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.baseName.text
        if name != "contentsOf", Lint.Framework.API.owners[name] != nil { sites.append(Site(node: Syntax(node), name: name)) }
        return .visitChildren
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        if name != "contentsOf", Lint.Framework.API.owners[name] != nil { sites.append(Site(node: Syntax(node), name: name)) }
        return .visitChildren
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let labels = node.arguments.compactMap { $0.label?.text }
        if labels.contains("resolvingBookmarkData") {
            sites.append(Site(node: Syntax(node), name: "resolvingBookmarkData"))
        } else if labels.first == "contentsOf", Self.callee(node) == "Data" {
            sites.append(Site(node: Syntax(node), name: "contentsOf"))
        }
        return .visitChildren
    }

    static func callee(_ node: FunctionCallExprSyntax) -> Swift::String? {
        if let reference = node.calledExpression.as(DeclReferenceExprSyntax.self) { return reference.baseName.text }
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self), member.declName.baseName.text == "init",
            let base = member.base?.as(DeclReferenceExprSyntax.self)
        {
            return base.baseName.text
        }
        return nil
    }
}
