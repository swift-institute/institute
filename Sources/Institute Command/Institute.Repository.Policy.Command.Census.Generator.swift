import Byte
import FIPS_180_4
import File_System
public import Institute_Model
public import Institute_Repository_Policy

import struct Swift.String

extension Institute.Repository.Policy.Command {
    /// The application half of the census: filesystem traversal over
    /// checked-out trees. The census document itself — rows, fields, CSV,
    /// normalization — stays with `Institute.Repository.Policy.Census`.
    public enum Census {}
}

extension Institute.Repository.Policy.Command.Census {
    /// Regenerates the census from checked-out trees at frozen heads.
    ///
    /// Semantics mirror the FT1 generator coordinate-for-coordinate;
    /// traversal order is deterministic (sorted), so parity against the
    /// FT1 artifact is order-normalized via `Census.normalized`.
    ///
    /// Excerpt digests compose onto the Institute FIPS 180-4 SHA-256
    /// witness (R37, swift-fips-180-4): pure, in-process, cross-platform.
    public struct Generator: Sendable {
        public struct Repo: Sendable {
            public let name: Swift.String
            public let root: Swift.String
            public let headSha: Swift.String

            public init(name: Swift.String, root: Swift.String, headSha: Swift.String) {
                self.name = name
                self.root = root
                self.headSha = headSha
            }
        }

        public enum Error: Swift.Error {
            case unreadable(path: Swift.String)
            /// A literal extraction pattern failed to compile — a
            /// programming error surfaced as a refusal so the census
            /// never silently drops a coordinate class.
            case pattern(Swift.String)
        }

        public let repos: [Repo]

        public init(repos: [Repo]) {
            self.repos = repos
        }
    }
}

extension Institute.Repository.Policy.Command.Census.Generator {
    typealias Row = Institute.Repository.Policy.Census.Row
    typealias Kind = Institute.Repository.Policy.Census.Kind

    static let skipCommands: Set<Swift.String> = [
        "if", "then", "else", "fi", "for", "do", "done", "while", "case",
        "esac", "echo", "printf", "exit", "set", "cd", "export", "shift",
        "local", "return", "true", "false", "read", "trap", "wait", "{",
        "}", "elif", "EOF",
    ]

    static let ownerByFamily: [Swift.String: Swift.String] = [
        "universal-or-wrapper-workflow": "CI Contract host projection (F12/F15)",
        "central-workflow": "named Swift owners (F2-F16)",
        "composite-action": "Workspace bootstrap + named owners (F10/F16)",
        "semantic-script": "named Swift owners (F2-F16)",
        "script-test": "owner test suites (F16)",
        "other": "FT1 adjudication",
    ]

    static func family(forPath path: Swift.String) -> Swift.String {
        if path.contains("/workflows/") && path.hasSuffix("swift-ci.yml") {
            return "universal-or-wrapper-workflow"
        }
        if path.contains("/workflows/") { return "central-workflow" }
        if path.contains("/actions/") { return "composite-action" }
        if path.contains("/scripts/tests/") { return "script-test" }
        if path.contains("/scripts/") { return "semantic-script" }
        return "other"
    }

    public func run() throws(Error) -> Institute.Repository.Policy.Census {
        var rows: [Row] = []
        for repo in repos {
            let githubRoot = repo.root + "/.github"
            for rel in Self.walk(root: repo.root, under: githubRoot) {
                try Self.rows(for: rel, repo: repo, into: &rows)
            }
        }
        rows.append(Self.leafCallerFamilyRow)
        rows.append(contentsOf: Self.sentinelRows)
        return Institute.Repository.Policy.Census(rows: rows)
    }

    // MARK: traversal

    static func names(at path: Swift.String) -> [Swift.String]? {
        guard let filePath = try? File.Path(path) else { return nil }
        guard let entries = try? File.Directory.Contents.list(at: .init(filePath)) else {
            return nil
        }
        return entries.map { Swift.String(lossy: $0.name) }
    }

    static func isDirectory(at path: Swift.String) -> Bool {
        guard let filePath = try? File.Path(path) else { return false }
        return File(filePath).stat.isDirectory
    }

    static func walk(root: Swift.String, under directory: Swift.String) -> [Swift.String] {
        var results: [Swift.String] = []
        var stack = [directory]
        while let dir = stack.popLast() {
            // An unlistable directory contributes no coordinates; absence
            // of the whole `.github` tree is the common, legitimate case.
            guard let entries = names(at: dir) else { continue }
            for entry in entries.sorted() {
                if entry == ".git" { continue }
                let full = dir + "/" + entry
                if isDirectory(at: full) {
                    stack.append(full)
                } else if entry.hasSuffix(".yml") || entry.hasSuffix(".yaml")
                    || entry.hasSuffix(".py") || entry.hasSuffix(".sh")
                {
                    results.append(Swift.String(full.dropFirst(root.count + 1)))
                }
            }
        }
        return results.sorted()
    }

    // MARK: per-file coordinates

    static func rows(
        for rel: Swift.String,
        repo: Repo,
        into rows: inout [Row]
    ) throws(Error) {
        let full = repo.root + "/" + rel
        guard let filePath = try? File.Path(full) else {
            throw Error.unreadable(path: full)
        }
        let raw: [Byte]
        do throws(Either<File.System.Read.Full.Error, Never>) {
            raw = try File(filePath).read.full { view in
                var storage = [Byte]()
                storage.reserveCapacity(view.count)
                for index in view.indices {
                    storage.append(view[index])
                }
                return storage
            }
        } catch {
            throw Error.unreadable(path: full)
        }
        let text = Swift.String(decoding: raw, as: Swift.UTF8.self)
        let fam = family(forPath: "/" + rel)
        guard let owner = ownerByFamily[fam] ?? ownerByFamily["other"] else {
            preconditionFailure("ownerByFamily names an owner for \"other\"")
        }
        let ext = rel.split(separator: ".").last.map(Swift.String.init) ?? ""
        let engine: Swift.String
        switch ext {
        case "py": engine = "python"
        case "sh": engine = "shell"
        case "yml", "yaml": engine = "actions-yaml"
        default: engine = "other"
        }
        func row(
            _ kind: Kind,
            _ id: Swift.String,
            line: Int,
            engine: Swift.String,
            digest: Swift.String,
            notes: Swift.String = ""
        ) -> Row {
            Row(
                repository: repo.name,
                headSha: repo.headSha,
                path: rel,
                coordinateKind: kind,
                coordinateId: id,
                line: line,
                engine: engine,
                excerptSha256: digest,
                family: fam,
                intendedOwner: owner,
                disposition: "reduce",
                notes: notes
            )
        }
        rows.append(
            row(
                .file,
                "file:\(rel)",
                line: 1,
                engine: engine,
                digest: digest(raw)
            )
        )
        guard engine == "actions-yaml" else { return }

        func lineNumber(at index: Swift.String.Index) -> Int {
            var count = 1
            for character in text[..<index] where character == "\n" {
                count += 1
            }
            return count
        }

        let expression = try Self.expression("\\$\\{\\{.*?\\}\\}").dotMatchesNewlines()
        var i = 0
        for match in text.matches(of: expression) {
            rows.append(
                row(
                    .expression,
                    "expr:\(rel):\(i)",
                    line: lineNumber(at: match.range.lowerBound),
                    engine: "actions-expression",
                    digest: digest(Swift.String(text[match.range]))
                )
            )
            i += 1
        }

        let uses = try Self.expression("^\\s*(?:-\\s+)?uses:\\s*(\\S+)")
            .anchorsMatchLineEndings()
        i = 0
        for match in text.matches(of: uses) {
            let target =
                match.output.count > 1
                ? match.output[1].substring.map(Swift.String.init) ?? ""
                : ""
            rows.append(
                row(
                    .usesEdge,
                    "uses:\(rel):\(i)",
                    line: lineNumber(at: match.range.lowerBound),
                    engine: "actions-yaml",
                    digest: digest(target),
                    notes: target
                )
            )
            i += 1
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(Swift.String.init)
        let runPattern = try Self.expression("^(\\s*)run:\\s*(\\||>|\\|-|>-)?")
            .anchorsMatchLineEndings()
        let command = try Self.expression("^\\s*([A-Za-z0-9_.\\/-]+)")
        i = 0
        for match in text.matches(of: runPattern) {
            let startLine = lineNumber(at: match.range.lowerBound)
            let indent =
                match.output.count > 1
                ? (match.output[1].substring?.count ?? 0)
                : 0
            let blockScalar =
                match.output.count > 2 && match.output[2].substring != nil
            var block: [Swift.String] = []
            if blockScalar {
                var j = startLine
                while j < lines.count {
                    let candidate = lines[j]
                    let stripped = candidate.trimmedASCIISpace
                    let candidateIndent =
                        candidate.count - candidate.drop { $0 == " " || $0 == "\t" }.count
                    if !stripped.isEmpty && candidateIndent <= indent { break }
                    block.append(candidate)
                    j += 1
                }
            } else {
                let rest = text[match.range.upperBound...]
                block = [Swift.String(rest.prefix { $0 != "\n" })]
            }
            let body = block.joined(separator: "\n")
            rows.append(
                row(
                    .runBlock,
                    "run:\(rel):\(i)",
                    line: startLine,
                    engine: "shell",
                    digest: digest(body)
                )
            )
            for (k, blockLine) in block.enumerated() {
                guard let commandMatch = try? command.firstMatch(in: blockLine),
                    commandMatch.output.count > 1,
                    let token = commandMatch.output[1].substring.map(Swift.String.init)
                else { continue }
                if skipCommands.contains(token) { continue }
                if blockLine.trimmedASCIISpace.hasPrefix("#") { continue }
                rows.append(
                    row(
                        .commandReference,
                        "cmd:\(rel):\(i):\(k)",
                        line: startLine + 1 + k,
                        engine: "shell",
                        digest: digest(token),
                        notes: token
                    )
                )
            }
            i += 1
        }
    }

    /// Compiles one literal extraction pattern, surfacing a
    /// non-compiling pattern as the typed `pattern` refusal.
    static func expression(_ pattern: Swift.String) throws(Error) -> Regex<AnyRegexOutput> {
        do {
            return try Regex(pattern)
        } catch {
            throw .pattern(pattern)
        }
    }

    /// Excerpt SHA-256 composed onto the Institute FIPS 180-4 witness
    /// (R37): a pure, in-process digest.
    static func digest(_ bytes: [Byte]) -> Swift.String {
        FIPS_180_4.SHA256.digest(bytes).hex
    }

    static func digest(_ text: Swift.String) -> Swift.String {
        digest([Byte](utf8: text))
    }

    // MARK: frozen family and sentinel rows

    static var leafCallerFamilyRow: Row {
        Row(
            repository: "17-organization fleet",
            headSha: "per-repo (review-inputs/reclosure/v1-per-root.json)",
            path: ".github/workflows/ci.yml",
            coordinateKind: .file,
            coordinateId: "family:leaf-callers",
            line: 1,
            engine: "actions-yaml",
            excerptSha256: "",
            family: "generated-leaf-caller",
            intendedOwner: "Repository Policy (generated projection; F13/F14)",
            disposition: "regenerate",
            notes:
                "449 callers; per-repo heads and caller blob SHAs frozen in v1-per-root.json (digest 56d8309c...)"
        )
    }

    static var sentinelRows: [Row] {
        let sentinels: [(Swift.String, Swift.String, Swift.String)] = [
            (
                "private-ordinary-repositories",
                "~182 private ordinary repositories: workflow bytes not enumerated in this public census",
                "R33 posture; private coordinates stay opaque in public artifacts"
            ),
            (
                "private-verification-private-side",
                "private verifier repository workflow/scripts not enumerated here",
                "split-credential boundary; owned by Private.Verification at F8"
            ),
            (
                "workspace-repo-automation",
                "swift-institute/Workspace repository automation not enumerated in this census pass",
                "Workspace owns its own package facts; F2 binds its API"
            ),
            (
                "skills-repo-automation",
                "swift-institute/Skills repository automation not enumerated in this census pass",
                "F17 owns Skills correspondence"
            ),
            (
                "swift-linter-repo-automation",
                "swift-foundations/swift-linter repository automation not enumerated in this census pass",
                "F9 owns linter parity"
            ),
        ]
        return sentinels.map { name, detail, cause in
            Row(
                repository: "sentinel",
                headSha: "",
                path: "",
                coordinateKind: .family,
                coordinateId: "sentinel:\(name)",
                line: 0,
                engine: "",
                excerptSha256: "",
                family: name,
                intendedOwner: "typed at owning transaction",
                disposition: "sentinel",
                measurement: "UNMEASURED",
                cause: cause,
                notes: detail
            )
        }
    }
}

extension Swift.String {
    /// The receiver without leading and trailing spaces and tabs — the
    /// whitespace stripping the census generator has always applied to
    /// run-block lines.
    fileprivate var trimmedASCIISpace: Swift.String {
        var value = Substring(self)
        while value.first == " " || value.first == "\t" { value = value.dropFirst() }
        while value.last == " " || value.last == "\t" { value = value.dropLast() }
        return Swift.String(value)
    }
}
