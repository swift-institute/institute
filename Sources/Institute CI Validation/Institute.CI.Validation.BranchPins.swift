import struct Swift.String
public import Institute_Model
public import Institute_CI_Model
import GitHub_Standard

extension Institute.CI.Validation {
    /// `[BRANCH-PIN-001]` — an Institute dependency must not be pinned to
    /// a moving branch.
    ///
    /// A green over a branch pin proves nothing about any tagged state:
    /// the thing that was green is not the thing a consumer will resolve
    /// tomorrow. Institute manifests therefore pin Institute
    /// dependencies to versions.
    ///
    /// **The ruled exception is exact-match on `main`**, not a general
    /// branch-pin amnesty (principal, 2026-07-30, recorded at
    /// `swift-standards/swift-mailgun-standard#13`): the Institute
    /// develops solely on `main`, tags are heritage and will not be cut,
    /// and an untagged Institute dependency is tracked with
    /// `branch: "main"`. Any *other* branch name on an Institute
    /// dependency still fires; a branch pin on a non-Institute
    /// dependency is outside the rule's scope regardless of its name.
    ///
    /// **This is a manifest text scan, deliberately** — not
    /// `swift package dump-package`. The JSON route needs a toolchain at
    /// or above every manifest's tools-version floor, which is exactly
    /// the trap that produced #61's 81% not-scanned. A text scan has no
    /// toolchain dependency and so cannot silently skip a target for
    /// environmental reasons. Comments are stripped first, string-aware
    /// and nesting-aware, and each `.package(` call is captured to its
    /// matching close paren, so a multiline declaration is one window
    /// and a commented-out declaration is invisible.
    public struct BranchPins: Validator {
        public static let rule: Rule = "BRANCH-PIN-001"
        public static let baselineRule: Rule = "BRANCH-PIN-BASELINE"

        public let rules: [Rule] = [Self.rule, Self.baselineRule]
        public let retiredScript: String? = ".github/scripts/validate-branch-pins.py"

        /// The organization manifest to read. `nil` locates it by walking
        /// up from the subject, which is what every in-repository
        /// invocation wants; a sweep over a foreign checkout names it.
        public let organizationsFile: String?

        /// A caller-supplied organization set. This is the compiled-control
        /// path: the Institute policy owner can provide its typed set directly
        /// without recreating the retired YAML transport beside the subject.
        public let organizations: Organizations?

        /// The burn-down ledger. `nil` is an empty ledger.
        public let baselineFile: String?

        public init(organizationsFile: String? = nil, baselineFile: String? = nil) {
            self.organizationsFile = organizationsFile
            self.organizations = nil
            self.baselineFile = baselineFile
        }

        public init(organizations: Organizations, baselineFile: String? = nil) {
            self.organizationsFile = nil
            self.organizations = organizations
            self.baselineFile = baselineFile
        }

        public func findings(in subject: Subject) throws(EnvironmentDefect) -> [Finding] {
            let organizations: Organizations
            if let supplied = self.organizations {
                organizations = supplied
            } else {
                let manifestPath =
                    organizationsFile
                    ?? Organizations.locateManifest(startingAt: subject.root)
                guard let manifestPath else {
                    throw .missingSupportFile(path: Organizations.manifestPath)
                }
                organizations = try Organizations.read(at: manifestPath)
            }
            let baseline = try Baseline.read(at: baselineFile)

            var findings: [Finding] = []
            for manifest in Self.manifests(in: subject.root) {
                guard let text = Institute.CI.Validation.text(at: subject.path(manifest))
                else { continue }
                let code = Self.strippingComments(text)
                for call in Self.packageCalls(in: code) {
                    guard let url = Self.dependencyURL(in: call),
                        let organization = Self.gitHubOrganization(of: url),
                        organizations.contains(organization),
                        let branch = Self.branchRequirement(in: call),
                        // Ruled convention: an untagged Institute
                        // dependency pinned to "main" is not a
                        // moving-target violation.
                        branch != "main"
                    else { continue }
                    let baselined = baseline.suppresses(repository: subject.repository, url: url)
                    findings.append(
                        Finding(
                            repository: subject.repository,
                            rule: baselined ? Self.baselineRule : Self.rule,
                            message: baselined
                                ? Self.baselinedMessage(
                                    manifest: manifest,
                                    url: url,
                                    branch: branch
                                )
                                : Self.message(manifest: manifest, url: url, branch: branch)
                        )
                    )
                }
            }
            return findings
        }

        // MARK: - Discovery

        /// Root manifests, sorted: `Package.swift` and
        /// `Package@swift-<version>.swift`, and nothing else. Sub-package
        /// manifests are out of scope — this rule is about what a
        /// repository declares as its own dependencies.
        static func manifests(in root: String) -> [String] {
            let names = (Institute.CI.Validation.names(at: root)) ?? []
            return names.filter(isRootManifestName).sorted()
        }

        static func isRootManifestName(_ name: String) -> Bool {
            guard name.hasPrefix("Package"), name.hasSuffix(".swift") else { return false }
            let middle = name.dropFirst("Package".count).dropLast(".swift".count)
            if middle.isEmpty { return true }
            guard middle.hasPrefix("@swift-") else { return false }
            let version = middle.dropFirst("@swift-".count)
            return !version.isEmpty && version.allSatisfy { $0.isNumber || $0 == "." }
        }

        // MARK: - Manifest scanning

        /// Remove `//` line comments and nested `/* */` block comments.
        ///
        /// String-aware, because `//` inside a string literal is every
        /// `https` URL in the file. Removed spans become spaces rather
        /// than vanishing, so offsets in the surviving code stay stable
        /// and tokens never fuse across a removal.
        ///
        /// Normalizes CRLF and bare CR to LF *before* the character-array
        /// conversion below. `Array(text)` decomposes into extended
        /// grapheme clusters, and CR+LF is itself one cluster — so every
        /// `character == "\n"` / `!= "\n"` comparison in this scan would
        /// never match a CRLF line ending. Concretely, the `//` line-
        /// comment loop below hunts for the next `"\n"` to know where the
        /// comment ends; on CRLF input it would never find one and
        /// consume the *entire rest of the file* as comment starting from
        /// the first `//` — which for a typical `// swift-tools-version:`
        /// header line is the very first line, blanking out every real
        /// `.package(...)` declaration this rule exists to scan. Manifest
        /// text read from a checkout is exactly `text` here (this rule
        /// reads bytes directly, not through the typed YAML reader), so a
        /// Windows checkout's CRLF-converted `Package.swift` hit this.
        static func strippingComments(_ text: String) -> String {
            let normalized =
                text
                .replacing("\r\n", with: "\n")
                .replacing("\r", with: "\n")
            let source = Array(normalized)
            var output = source
            var index = 0
            var inString = false
            var blockDepth = 0
            func next(_ offset: Int) -> Character? {
                index + offset < source.count ? source[index + offset] : nil
            }
            while index < source.count {
                let character = source[index]
                if blockDepth > 0 {
                    if character == "/", next(1) == "*" {
                        blockDepth += 1
                        output[index] = " "
                        output[index + 1] = " "
                        index += 2
                        continue
                    }
                    if character == "*", next(1) == "/" {
                        blockDepth -= 1
                        output[index] = " "
                        output[index + 1] = " "
                        index += 2
                        continue
                    }
                    if character != "\n" { output[index] = " " }
                    index += 1
                    continue
                }
                if inString {
                    if character == "\\" {
                        index += 2
                        continue
                    }
                    if character == "\"" { inString = false }
                    index += 1
                    continue
                }
                if character == "\"" {
                    inString = true
                    index += 1
                    continue
                }
                if character == "/", next(1) == "/" {
                    while index < source.count, source[index] != "\n" {
                        output[index] = " "
                        index += 1
                    }
                    continue
                }
                if character == "/", next(1) == "*" {
                    blockDepth = 1
                    output[index] = " "
                    output[index + 1] = " "
                    index += 2
                    continue
                }
                index += 1
            }
            return String(output)
        }

        /// The text of each `.package(…)` call, close-paren matched.
        ///
        /// Runs on comment-stripped code and tracks string state, so
        /// parens inside literals cannot unbalance the window. An
        /// unterminated call runs to end of file: a malformed manifest is
        /// not this validator's finding to make.
        static func packageCalls(in code: String) -> [String] {
            let characters = Array(code)
            let token = Array(".package" as Swift.String)
            var calls: [String] = []
            var start = 0
            while start + token.count <= characters.count {
                guard Array(characters[start..<(start + token.count)]) == token else {
                    start += 1
                    continue
                }
                var open = start + token.count
                while open < characters.count,
                    characters[open] == " " || characters[open] == "\t"
                        || characters[open] == "\n"
                {
                    open += 1
                }
                guard open < characters.count, characters[open] == "(" else {
                    start += 1
                    continue
                }
                var index = open + 1
                var depth = 1
                var inString = false
                while index < characters.count, depth > 0 {
                    let character = characters[index]
                    if inString {
                        if character == "\\" {
                            index += 2
                            continue
                        }
                        if character == "\"" { inString = false }
                    } else if character == "\"" {
                        inString = true
                    } else if character == "(" {
                        depth += 1
                    } else if character == ")" {
                        depth -= 1
                    }
                    index += 1
                }
                calls.append(String(characters[start..<min(index, characters.count)]))
                start += token.count
            }
            return calls
        }

        /// The `url:` argument of a `.package(…)` call.
        static func dependencyURL(in call: String) -> String? {
            Self.quotedValue(in: call, afterLabel: "url:")
        }

        /// The branch a call pins to, in either spelling —
        /// `branch: "x"` or the legacy `.branch("x")`. The labelled form
        /// wins when both appear, matching the retired scan order.
        static func branchRequirement(in call: String) -> String? {
            if let labelled = Self.quotedValue(in: call, afterLabel: "branch:") { return labelled }
            return Self.legacyBranchValue(in: call)
        }

        /// The GitHub organization a dependency URL names, when the URL is
        /// exactly `https://github.com/<org>/<repo>` with an optional
        /// `.git` suffix. A URL with any other shape — a different host,
        /// a deeper path — is not a GitHub organization reference.
        static func gitHubOrganization(of url: String) -> String? {
            let prefix = "https://github.com/"
            guard url.hasPrefix(prefix) else { return nil }
            let path = url.dropFirst(prefix.count)
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty
            else { return nil }
            return String(components[0])
        }

        /// The double-quoted value that follows `label` — `url: "…"`,
        /// `branch: "…"` — allowing any run of whitespace between them.
        static func quotedValue(in text: String, afterLabel label: String) -> String? {
            let characters = Array(text)
            let token = Array(label)
            var start = 0
            while start + token.count <= characters.count {
                guard Array(characters[start..<(start + token.count)]) == token else {
                    start += 1
                    continue
                }
                var index = start + token.count
                while index < characters.count, characters[index].isWhitespace { index += 1 }
                guard index < characters.count, characters[index] == "\"" else {
                    start += 1
                    continue
                }
                index += 1
                let open = index
                while index < characters.count, characters[index] != "\"" { index += 1 }
                // `[^"]+` for a URL, `[^"]*` for a branch: an empty branch
                // name is a real, if absurd, pin and the retired scan
                // reported it.
                guard index < characters.count else {
                    start += 1
                    continue
                }
                let value = String(characters[open..<index])
                if label == "url:", value.isEmpty {
                    start += 1
                    continue
                }
                return value
            }
            return nil
        }

        /// The legacy requirement spelling, `.branch("x")`.
        static func legacyBranchValue(in text: String) -> String? {
            let characters = Array(text)
            let token = Array(".branch(" as Swift.String)
            var start = 0
            while start + token.count <= characters.count {
                guard Array(characters[start..<(start + token.count)]) == token else {
                    start += 1
                    continue
                }
                var index = start + token.count
                while index < characters.count, characters[index].isWhitespace { index += 1 }
                guard index < characters.count, characters[index] == "\"" else {
                    start += 1
                    continue
                }
                index += 1
                let open = index
                while index < characters.count, characters[index] != "\"" { index += 1 }
                guard index < characters.count else {
                    start += 1
                    continue
                }
                let value = String(characters[open..<index])
                index += 1
                while index < characters.count, characters[index].isWhitespace { index += 1 }
                guard index < characters.count, characters[index] == ")" else {
                    start += 1
                    continue
                }
                return value
            }
            return nil
        }

        // MARK: - Messages

        static func message(manifest: String, url: String, branch: String) -> String {
            "\(manifest): `\(url)` pinned to branch \"\(branch)\" — Institute dependencies "
                + "pin to versions; a branch is a moving target"
        }

        static func baselinedMessage(manifest: String, url: String, branch: String) -> String {
            "\(manifest): `\(url)` pinned to branch \"\(branch)\" — baselined; burn-down "
                + "owned by the package/release record"
        }
    }
}
