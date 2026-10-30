public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `path name grammar` = Lint.Rule(
        id: "path name grammar",
        default: .warning,
        controls: [
            .init(
                id: "path name grammar concatenated directory",
                source: "struct Command {}",
                path: "Sources/InstituteArchitectureCLI/Command.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "path name grammar spaced directory",
                source: "struct Command {}",
                path: "Sources/Institute Architecture CLI/Command.swift",
                expectation: .clean
            ),
            .init(
                id: "path name grammar out of surface",
                source: "struct Command {}",
                path: "Plugins/BadPluginName/Plugin.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            namingPathGrammarFindings(
                source: source.file,
                severity: severity,
                tree: source.tree
            )
        }
    )
}

internal func namingPathGrammarDirectoryIsExempt(_ segment: Swift::String) -> Swift::Bool {
    if segment.hasSuffix(".docc") { return true }
    if segment == ".snapshots" { return true }
    return false
}

internal func namingPathGrammarSnapshotDirectoryIsInvalid(
    _ segment: Swift::String
) -> Swift::Bool {
    guard segment != ".snapshots" else { return false }
    return segment.filter { $0.isLetter }.lowercased() == "snapshots"
}

internal func namingPathGrammarCompoundWords(in segment: Swift::String) -> [Swift::String] {
    segment.split(separator: " ").map(Swift::String.init).filter(namingWordIsCompound)
}

@usableFromInline
internal func namingPathGrammarDirectoryMessage(
    segment: Swift::String,
    words: [Swift::String]
) -> Swift::String {
    "[path name grammar]: directory '\(segment)' contains concatenated "
        + "word\(words.count == 1 ? "" : "s") "
        + words.map { "'\($0)'" }.joined(separator: ", ")
        + " — directory names use the spaced Nest.Name form "
        + "(e.g. `Institute Architecture CLI`); rename the directory"
}

@usableFromInline
internal func namingPathGrammarSnapshotDirectoryMessage(
    segment: Swift::String
) -> Swift::String {
    "[path name grammar]: snapshot-reference directory '\(segment)' uses a "
        + "noncanonical spelling — rename the directory to `.snapshots`"
}

@usableFromInline
internal func namingPathGrammarBasenameMessage(
    segment: Swift::String,
    basename: Swift::String
) -> Swift::String {
    "[path name grammar]: file name segment '\(segment)' in "
        + "'\(basename).swift' is a concatenated compound — file names are "
        + "the declared type's dotted Nest.Name path "
        + "(e.g. `Institute.Architecture.CLI.swift`); rename the file"
}

internal func namingPathGrammarFindings(
    source: Source.File,
    severity: Diagnostic.Severity,
    tree: SourceFileSyntax
) -> [Diagnostic.Record] {
    let path = source.filePath
    let parts = path.split(separator: "/", omittingEmptySubsequences: true).map(Swift::String.init)
    guard parts.count >= 2 else { return [] }
    guard let rootIndex = parts.firstIndex(where: { $0 == "Sources" || $0 == "Tests" })
    else { return [] }
    guard let filename = parts.last else { return [] }
    guard filename.hasSuffix(".swift") else { return [] }

    var records: [Diagnostic.Record] = []
    func emit(_ message: Swift::String) {
        guard !records.contains(where: { $0.message == message }) else { return }
        records.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: 1,
                    column: 1
                ),
                severity: severity,
                identifier: "path name grammar",
                message: message
            )
        )
    }

    let firstDirectory = parts.index(after: rootIndex)
    let fileIndex = parts.index(before: parts.endIndex)
    for segment in parts[firstDirectory..<fileIndex] {
        if namingPathGrammarSnapshotDirectoryIsInvalid(segment) {
            emit(namingPathGrammarSnapshotDirectoryMessage(segment: segment))
            continue
        }
        guard !namingPathGrammarDirectoryIsExempt(segment) else { continue }
        let words = namingPathGrammarCompoundWords(in: segment)
        if !words.isEmpty {
            emit(namingPathGrammarDirectoryMessage(segment: segment, words: words))
        }
    }

    var basename = Swift::String(filename.dropLast(".swift".count))
    if let plusIndex = basename.firstIndex(of: "+") {
        basename = Swift::String(basename[basename.startIndex..<plusIndex])
    }
    if let whereRange = basename.range(of: " where ") {
        basename = Swift::String(basename[basename.startIndex..<whereRange.lowerBound])
    }
    let collector = NamingPathGrammarPrimaryTypeCollector()
    collector.walk(tree)
    guard collector.declaresPrimaryType else { return records }
    for segment in basename.split(separator: ".").map(Swift::String.init) {
        if namingWordIsCompound(segment) {
            emit(
                namingPathGrammarBasenameMessage(
                    segment: segment,
                    basename: Swift::String(filename.dropLast(".swift".count))
                )
            )
        }
    }
    return records
}

internal final class NamingPathGrammarPrimaryTypeCollector: SyntaxVisitor {
    var declaresPrimaryType: Swift::Bool = false

    init() { super.init(viewMode: .sourceAccurate) }

    private func isPrimary(_ decl: DeclSyntax) -> Swift::Bool {
        if let classDecl = decl.as(ClassDeclSyntax.self) {
            return !Naming.Visitor.extends(classDecl.inheritanceClause)
        }
        return decl.is(StructDeclSyntax.self)
            || decl.is(EnumDeclSyntax.self)
            || decl.is(ActorDeclSyntax.self)
            || decl.is(ProtocolDeclSyntax.self)
    }

    override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
        for item in Lint.Syntax.Conditional.statements(node.statements) {
            guard case .decl(let decl) = item.item else { continue }
            if let extensionDecl = decl.as(ExtensionDeclSyntax.self) {
                for member in extensionDecl.memberBlock.members where isPrimary(member.decl) {
                    declaresPrimaryType = true
                    return .skipChildren
                }
                continue
            }
            if isPrimary(decl) {
                declaresPrimaryType = true
                return .skipChildren
            }
        }
        return .skipChildren
    }
}
