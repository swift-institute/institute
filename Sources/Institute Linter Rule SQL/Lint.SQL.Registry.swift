package import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.SQL {

    package struct Registry: Sendable {

        package let exceptions: Lint.SQL.Exceptions

        package init(exceptions: Lint.SQL.Exceptions) {
            self.exceptions = exceptions
        }
    }
}

extension Lint.SQL.Registry {

    package static let identifier: Swift::String = "sql registry"

    package static let schemaSuffix: Swift::String = " Schema"

    package static let scope: Swift::String =
        "This rule checks that every `#sql` site outside a `… Schema` target is listed in "
        + "`Lint.SQL.Exceptions` with a one-line reason, and that a reason saying \"missing\" or "
        + "\"lacks\" carries a `swift-compositions/swift-sql#<n>` link; it does not check that the "
        + "reason is sound."

    package func observe(
        _ source: borrowing Lint.Source.Parsed,
        severity: Diagnostic.Severity
    ) -> Lint.Rule.Observation {
        var findings: [Diagnostic.Record] = []
        if source.path.underlying == "Package.swift" {
            findings += registry(source, severity: severity)
        }
        guard !Lint.Scope.Target.named(source.path, suffix: Self.schemaSuffix), !Lint.Scope.Target.isTest(source.path) else {
            return Lint.Rule.Observation(
                findings: findings,
                coverage: .measured,
                applicability: findings.isEmpty ? .inapplicable : .applicable
            )
        }
        findings += sites(source, severity: severity)
        return Lint.Rule.Observation(findings: findings, coverage: .measured)
    }

    fileprivate func sites(
        _ source: borrowing Lint.Source.Parsed,
        severity: Diagnostic.Severity
    ) -> [Diagnostic.Record] {
        let visitor = Visitor()
        visitor.walk(source.tree)
        let file = source.path.underlying
        let listed = exceptions.entries(in: file)
        var order: [Swift::String] = []
        var groups: [Swift::String: [Syntax]] = [:]
        for site in visitor.sites {
            let declaration = Lint.Scope.Declaration.identity(of: site)
            if groups[declaration] == nil { order.append(declaration) }
            groups[declaration, default: []].append(site)
        }
        var findings: [Diagnostic.Record] = []
        for declaration in order {
            let group = groups[declaration] ?? []
            guard let entry = listed.first(where: { $0.declaration == declaration }) else {
                for site in group {
                    findings.append(
                        Lint.Scope.record(
                            at: site,
                            in: source,
                            severity: severity,
                            identifier: Self.identifier,
                            message: "[sql registry]: `#sql` in `\(declaration)` of `\(file)` is not listed in "
                                + "`Lint.SQL.Exceptions`. \(Self.scope) Fix: express it with swift-sql, move it "
                                + "into the `… Schema` target, or list it as `.init(file: \"\(file)\", "
                                + "declaration: \"\(declaration)\", reason: \"…\")`."
                        )
                    )
                }
                continue
            }
            if entry.sites != group.count, let first = group.first {
                findings.append(
                    Lint.Scope.record(
                        at: first,
                        in: source,
                        severity: severity,
                        identifier: Self.identifier,
                        message: "[sql registry]: \(entry.label) is listed with \(entry.sites) `#sql` "
                            + "site(s) but has \(group.count). \(Self.scope) Fix: set `sites: \(group.count)` "
                            + "after checking each site's reason, or remove the extra sites."
                    )
                )
            }
        }
        for entry in listed where groups[entry.declaration] == nil {
            findings.append(
                Lint.Scope.record(
                    at: source.tree,
                    in: source,
                    severity: severity,
                    identifier: Self.identifier,
                    message: "[sql registry]: stale entry: \(entry.label) is listed in `Lint.SQL.Exceptions` "
                        + "but that declaration has no `#sql` site in this file. \(Self.scope) Fix: remove the "
                        + "entry, or correct its declaration to the identity this rule reports."
                )
            )
        }
        return findings
    }

    fileprivate func registry(
        _ source: borrowing Lint.Source.Parsed,
        severity: Diagnostic.Severity
    ) -> [Diagnostic.Record] {
        let root = Lint.Scope.File.root(of: source)
        var findings: [Diagnostic.Record] = []
        var seen: Swift::Set<Swift::String> = []
        for entry in exceptions.entries {
            for problem in Self.problems(of: entry, root: root, seen: &seen) {
                findings.append(
                    Lint.Scope.record(
                        at: source.tree,
                        in: source,
                        severity: severity,
                        identifier: Self.identifier,
                        message: "[sql registry]: \(entry.label): \(problem) \(Self.scope)"
                    )
                )
            }
        }
        return findings
    }

    package static func problems(
        of entry: Lint.SQL.Exception,
        root: Swift::String?,
        seen: inout Swift::Set<Swift::String>
    ) -> [Swift::String] {
        var problems: [Swift::String] = []
        let key = entry.file + "\u{0}" + entry.declaration
        if !seen.insert(key).inserted {
            problems.append("listed more than once. Fix: keep one entry and set `sites:`.")
        }
        let reason = entry.reason.trimmingWhitespace
        if reason.isEmpty {
            problems.append("the reason is empty. Fix: say in one line why swift-sql cannot express it.")
        }
        if entry.reason.contains(where: { $0.isNewline }) {
            problems.append("the reason spans more than one line. Fix: state it in one line.")
        }
        if Self.namesMissingAPI(reason), !Self.linksIssue(reason) {
            problems.append(
                "the reason names a missing API but carries no `swift-compositions/swift-sql#<n>` "
                    + "reference. Fix: file or find the swift-sql issue and cite it in the reason."
            )
        }
        if entry.sites < 1 {
            problems.append("`sites` is \(entry.sites). Fix: list the number of `#sql` sites (at least 1).")
        }
        if Lint.Scope.Target.named(Lint.Source.Path(entry.file), suffix: schemaSuffix) {
            problems.append(
                "stale entry: the file is in a `… Schema` target, where `#sql` needs no listing. "
                    + "Fix: remove the entry."
            )
        }
        if let root, !Lint.Scope.File.isFile(root + "/" + entry.file) {
            problems.append(
                "stale entry: the file does not exist. Fix: remove the entry or correct its path "
                    + "(relative to the package root)."
            )
        }
        return problems
    }

    package static func namesMissingAPI(_ reason: Swift::String) -> Swift::Bool {
        let words = reason.lowercased().split(whereSeparator: { !($0.isASCII && $0.isLetter) })
        return words.contains("missing") || words.contains("lacks")
    }

    package static func linksIssue(_ reason: Swift::String) -> Swift::Bool {
        let marker = "swift-compositions/swift-sql#"
        var remainder = reason[...]
        while let range = remainder.range(of: marker) {
            let after = remainder[range.upperBound...]
            if let first = after.first, first.isASCII, first.isNumber {
                return true
            }
            remainder = after
        }
        return false
    }
}

extension Lint.SQL.Registry {

    fileprivate final class Visitor: SyntaxVisitor {
        var sites: [Syntax] = []

        init() {
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
            if node.macroName.text == "sql" { sites.append(Syntax(node)) }
            return .visitChildren
        }

        override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
            if node.macroName.text == "sql" { sites.append(Syntax(node)) }
            return .visitChildren
        }
    }
}

extension Swift::String {

    fileprivate var trimmingWhitespace: Swift::String {
        var slice = self[...]
        while let first = slice.first, first.isWhitespace { slice = slice.dropFirst() }
        while let last = slice.last, last.isWhitespace { slice = slice.dropLast() }
        return Swift::String(slice)
    }
}
