import GitHub_Standard
public import Institute_CI_Model
import Institute_CI_Workflow
public import Institute_Model
import Standard_Library_Extensions

import struct Swift.String

extension Institute.CI.Validation {
    /// `[README-*]` — README files conform to the readme skill family
    /// rules.
    ///
    /// The Swift owner of `.github/scripts/validate-readme.py` (Wave 2b
    /// finalization, 2026-05-10). The repository's `readme.family` in
    /// `.github/metadata.yaml` — per Wave 2b Decision 7 — routes it to a
    /// per-family rule subset:
    ///
    /// - **Universal** — `README-017` (exactly one H1, first non-empty
    ///   line), `README-026` (no internal rule-ID citations outside code
    ///   blocks).
    /// - **Family E** (sub-package) — `README-016` (no Roadmap/TODO/Changelog),
    ///   `README-160` (only what Swift cannot express: no section but
    ///   `## Laws`, no code block, no `.package(` snippet). `README-003`
    ///   was removed 2026-07-30, superseded in full by
    ///   swift-institute/.github#126. `README-001` (License section),
    ///   `README-008` (Installation section) and `README-013` (Error
    ///   Handling section) were removed 2026-11-03: the code is meant to be
    ///   self-evident, and a README holds only what the language cannot
    ///   say; an error type is already in `throws(...)` (Coen, 3 Nov).
    ///   Retired rule IDs are never recycled. `README-161` (the first line is
    ///   `# <repository name>`) and `README-162` (one paragraph before
    ///   `## Laws`) complete the shape (Coen, 4 Nov).
    /// - **Family C** (process) — `README-137` (no Installation, badges,
    ///   or Quick Start), `README-138` (length budget).
    /// - **Family F** (placeholder) — `README-150` (H1 + status
    ///   blockquote only), `README-151` (status value in the canonical
    ///   set). A Family F repository without a README is clean: absence
    ///   *is* the namespace reservation.
    /// - **Family G** (org profile) — `README-117` (no section but
    ///   `## Start here`, no code block), which supersedes `README-116`. The
    ///   control organization's profile is the Institute's entry point, so
    ///   it is the one profile the shape doesn't bind. The profile lives at
    ///   repo-root `profile/README.md` when the subject IS the org's
    ///   `.github` repository, and at `.github/profile/README.md` otherwise.
    ///
    /// A repository whose metadata declares `readme.exempt:
    /// vendored-upstream` is skipped and emits nothing — out of scope by
    /// decision, not unclassified by omission. A repository with neither
    /// `family` nor a recognised exemption is `README-family-unset`,
    /// which reads as an oversight rather than a pass.
    ///
    /// ## Correspondence surface
    ///
    /// `exemptions` and `families` mirror the `readme.exempt` and
    /// `readme.family` enums in `metadata-schema.json`. The retired
    /// script's copies (`EXEMPTIONS` / `FAMILIES`) are still the ones the
    /// `[GH-REPO-063]` guard (`validate-schema-workflow-keys.py`) reads
    /// with `ast`, which is why that script is retained after this port —
    /// the guard's re-specification against a Swift consumer follows the
    /// port (swift-institute/.github#404) rather than riding it.
    ///
    /// Message spellings that carry Python `repr` formatting are rendered
    /// through `Retired`, because byte-identity of the sorted TSV against
    /// the retired implementation is the port's one unwaived gate.
    public struct Readme: Validator {
        public let rules: [Rule] = [
            "README-016",
            "README-017",
            "README-026",
            "README-117",
            "README-137",
            "README-138",
            "README-150",
            "README-151",
            "README-160",
            "README-161",
            "README-162",
            "README-family-unset",
            "README-presence",
            "README-read-failed",
        ]
        /// Declared exemptions from family routing, per
        /// `metadata-schema.json` `readme.exempt`.
        public static let exemptions: Set<String> = ["vendored-upstream"]

        /// Accepted `readme.family` letters, per `metadata-schema.json`
        /// `readme.family`. B and D are deliberately absent, not retired.
        public static let families: Set<String> = ["A", "C", "E", "F", "G"]

        static let statusValues: Set<String> = [
            "Pre-implementation", "Namespace-reservation", "Unnecessary", "Archived",
        ]

        typealias Pattern = Institute.CI.Validation.SkillHygiene.Pattern

        /// Internal rule-ID citations — `[README-017]`,
        /// `[PLAT-ARCH-008e]` — as the retired `FORBIDDEN_RULE_ID` spelled
        /// them. The curated first segment separates an internal ID from
        /// an external standards citation such as `[RFC-7231]`.
        static let forbiddenRuleID = Pattern(
            #"\[(README|MEM|DOC|API|MOD|PRIM|IMPL|PLAT|ARCH|TEST|SWIFT-TEST|BENCH|INST-TEST|"#
                + #"PATTERN|GH-REPO|SKILL|RES|EXP|BLOG|REFL|AUDIT|CONV|IDX|LEG|NL-WET|RL|"#
                + #"COPY|SEM|API-NAME|API-ERR|API-IMPL|API-LAYER|MEM-COPY|MEM-OWN|MEM-LIFE|"#
                + #"MEM-LINEAR|MEM-REF|MEM-SAFE|MEM-SEND|MEM-UNSAFE|MEM-SPAN|"#
                + #"INFRA|MOD-EXCEPT|CI|README-PROC|SOC|SUPER|HANDOFF|COLLAB|GIT|"#
                + #"FREVIEW|SAVE|DOC-MARKUP|RELEASE|META|REFL-PROC|SKILL-CREATE|"#
                + #"SKILL-LIFE|REFL-PROC)(?:-[A-Z][A-Z0-9]*)*-[0-9]+[a-z]?\]"#
        )

        static let h1Line = Pattern(#"^#\s+\S"#)
        static let h2Line = Pattern(#"^##\s+\S"#)
        static let h2OrDeeper = Pattern(#"^#{2,6}\s+\S"#)
        static let fencedBlock = Pattern(#"```.*?```"#, dotMatchesNewlines: true)
        static let installDependency = Pattern(#"\.package\("#)
        static let statusLine = Pattern(#">\s*\*\*Status:\s*([^*]+?)\*\*"#)

        public init() {}

        public func findings(in subject: Subject) throws(EnvironmentDefect) -> [Finding] {
            guard let family = Self.family(of: subject) else {
                return [
                    Finding(
                        repository: subject.repository,
                        rule: "README-family-unset",
                        message: ".github/metadata.yaml lacks readme.family field; "
                            + "cannot apply per-family rules"
                    )
                ]
            }
            if family == "exempt" {
                return []
            }

            let relative = Self.readmePath(family: family, repository: subject.repository)
            let content: String?
            do {
                content = try subject.text(at: relative)
            } catch {
                return [
                    Finding(
                        repository: subject.repository,
                        rule: "README-read-failed",
                        message: "\(subject.path(relative)): could not be read"
                    )
                ]
            }
            guard let content else {
                if family == "F" {
                    return []
                }
                return [
                    Finding(
                        repository: subject.repository,
                        rule: "README-presence",
                        message: "family=\(family) but README not found at expected path "
                            + relative
                    )
                ]
            }

            let name = relative.finalPathComponent
            var findings = Self.universal(subject.repository, name: name, content: content)
            switch family {
            case "E":
                findings += Self.familyE(subject, name: name, content: content)

            case "C":
                findings += Self.familyC(subject.repository, name: name, content: content)

            case "F":
                findings += Self.familyF(subject.repository, name: name, content: content)

            case "G":
                findings += Self.familyG(subject.repository, name: name, content: content)

            default:
                break
            }
            return findings
        }
    }
}

extension Institute.CI.Validation.Readme {
    /// The family letter, `"exempt"`, or `nil` when unset — the retired
    /// `detect_family`, including its posture that every way of
    /// not-knowing (absent file, unreadable file, unparseable YAML, a
    /// non-mapping where a mapping belongs) is `None`, not an error.
    static func family(of subject: Institute.CI.Validation.Subject) -> String? {
        let document: Institute.CI.Workflow.YAML.Node
        do {
            guard let text = try subject.text(at: ".github/metadata.yaml") else { return nil }
            document = try Institute.CI.Workflow.YAML.Parser.parse(text)
        } catch {
            return nil
        }
        guard let top = document.mapping,
            let readme = top["readme"]?.mapping
        else { return nil }
        if let exempt = readme["exempt"]?.text, exemptions.contains(exempt) {
            return "exempt"
        }
        if let family = readme["family"]?.text, families.contains(family) {
            return family
        }
        return nil
    }

    /// Where the family's README lives, relative to the subject root.
    ///
    /// Family G org profiles live in the org's special `.github` repo at
    /// `profile/README.md`. When the repository under validation IS that
    /// `.github` repo, the profile is at repo-root `profile/README.md` —
    /// not a nested `.github/profile/README.md`, which is the
    /// org-relative view and wrong inside the repo itself.
    static func readmePath(family: String, repository: GitHub_Standard::GitHub.Repository.Slug) -> String {
        guard family == "G" else { return "README.md" }
        let lastComponent = repository.description.split(separator: "/").last.map(String.init) ?? repository.description
        return lastComponent == ".github"
            ? "profile/README.md"
            : ".github/profile/README.md"
    }

    /// Fenced ``` … ``` code blocks removed, for the rule-citation and
    /// H1 scans.
    static func strippingCodeBlocks(_ text: String) -> String {
        var result = ""
        var cursor = text.startIndex
        for match in fencedBlock.matches(in: text) {
            result += text[cursor..<match.range.lowerBound]
            cursor = match.range.upperBound
        }
        result += text[cursor...]
        return result
    }

    /// `str.splitlines()` — no trailing empty line for a trailing
    /// newline, and `\r`, `\n`, `\r\n` each terminate a line. The
    /// distinction is load-bearing for `README-138`'s line count.
    static func splitLines(_ text: String) -> [Substring] {
        var lines: [Substring] = []
        var start = text.startIndex
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\n" || character == "\r" || character == "\r\n" {
                lines.append(text[start..<index])
                index = text.index(after: index)
                start = index
            } else {
                index = text.index(after: index)
            }
        }
        if start < text.endIndex { lines.append(text[start...]) }
        return lines
    }

    /// The first `limit` code points, as Python's `[:n]` slices.
    static func prefix(_ text: some StringProtocol, _ limit: Int) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.prefix(limit)))
    }

    static func universal(
        _ repository: GitHub_Standard::GitHub.Repository.Slug,
        name: String,
        content: String
    ) -> [Institute.CI.Validation.Finding] {
        typealias Finding = Institute.CI.Validation.Finding
        var findings: [Finding] = []
        let lines = splitLines(content)
        let nonblank = lines.filter {
            !$0.trimmedWhitespace.isEmpty
        }
        let stripped = strippingCodeBlocks(content)
        let h1Count = splitLines(stripped)
            .count { h1Line.firstMatch(in: String($0)) != nil }
        if h1Count == 0 {
            findings.append(
                Finding(
                    repository: repository,
                    rule: "README-017",
                    message: "\(name): missing H1 title (first heading must be `# `)"
                )
            )
        } else if h1Count > 1 {
            findings.append(
                Finding(
                    repository: repository,
                    rule: "README-017",
                    message: "\(name): \(h1Count) H1 headings found; exactly one required"
                )
            )
        }
        if let first = nonblank.first, h1Line.firstMatch(in: String(first)) == nil {
            findings.append(
                Finding(
                    repository: repository,
                    rule: "README-017",
                    message: "\(name): first non-empty line is not H1 "
                        + "(got \(Institute.CI.Validation.Retired.quoted(prefix(first, 80))))"
                )
            )
        }
        if let match = forbiddenRuleID.firstMatch(in: stripped) {
            findings.append(
                Finding(
                    repository: repository,
                    rule: "README-026",
                    message: "\(name): contains internal rule-ID citation \(match.whole) "
                        + "(forbidden in published READMEs)"
                )
            )
        }
        return findings
    }

    static func familyE(
        _ subject: Institute.CI.Validation.Subject,
        name: String,
        content: String
    ) -> [Institute.CI.Validation.Finding] {
        typealias Finding = Institute.CI.Validation.Finding
        var findings: [Finding] = []
        for line in splitLines(content) where h2OrDeeper.firstMatch(in: String(line)) != nil {
            let heading = String(line).trimmedWhitespace
            guard heading != "## Laws" else { continue }
            findings.append(
                Finding(
                    repository: subject.repository,
                    rule: "README-160",
                    message: "\(name): contains section "
                        + Institute.CI.Validation.Retired.quoted(heading)
                        + "; a README's only section is `## Laws`"
                )
            )
        }
        if content.contains("```") {
            findings.append(
                Finding(
                    repository: subject.repository,
                    rule: "README-160",
                    message: "\(name): contains a code block; the tests are the examples"
                )
            )
        }
        if installDependency.firstMatch(in: content) != nil {
            findings.append(
                Finding(
                    repository: subject.repository,
                    rule: "README-160",
                    message: "\(name): contains a `.package(` snippet, which repeats Package.swift"
                )
            )
        }
        let repository =
            subject.repository.description.split(separator: "/").last.map(String.init)
            ?? subject.repository.description
        let lines = splitLines(content)
        if let first = lines.first(where: { !$0.trimmedWhitespace.isEmpty }),
            String(first).trimmedWhitespace != "# \(repository)"
        {
            findings.append(
                Finding(
                    repository: subject.repository,
                    rule: "README-161",
                    message: "\(name): first line is "
                        + Institute.CI.Validation.Retired.quoted(prefix(first, 80))
                        + "; it must be `# \(repository)`"
                )
            )
        }
        let paragraphs = paragraphCount(in: lines)
        if paragraphs != 1 {
            findings.append(
                Finding(
                    repository: subject.repository,
                    rule: "README-162",
                    message: "\(name): has \(paragraphs) paragraphs before `## Laws`; it must have one"
                )
            )
        }
        for forbidden in ["## Roadmap", "## TODO", "## Changelog"]
        where content.contains(forbidden) {
            findings.append(
                Finding(
                    repository: subject.repository,
                    rule: "README-016",
                    message: "\(name): contains forbidden section "
                        + Institute.CI.Validation.Retired.quoted(forbidden)
                )
            )
        }
        return findings
    }

    /// The paragraphs after the title and before the first section.
    static func paragraphCount(in lines: [Substring]) -> Int {
        var count = 0
        var inParagraph = false
        for line in lines {
            let text = String(line)
            if h2OrDeeper.firstMatch(in: text) != nil { break }
            if h1Line.firstMatch(in: text) != nil || line.trimmedWhitespace.isEmpty {
                inParagraph = false
            } else if !inParagraph {
                inParagraph = true
                count += 1
            }
        }
        return count
    }

    static func familyC(
        _ repository: GitHub_Standard::GitHub.Repository.Slug,
        name: String,
        content: String
    ) -> [Institute.CI.Validation.Finding] {
        typealias Finding = Institute.CI.Validation.Finding
        var findings: [Finding] = []
        if content.contains("## Installation") {
            findings.append(
                Finding(
                    repository: repository,
                    rule: "README-137",
                    message: "\(name): process README has `## Installation` section (forbidden)"
                )
            )
        }
        if content.hasPrefix("![") {
            findings.append(
                Finding(
                    repository: repository,
                    rule: "README-137",
                    message: "\(name): process README has badges (forbidden)"
                )
            )
        }
        if content.contains("## Quick Start") {
            findings.append(
                Finding(
                    repository: repository,
                    rule: "README-137",
                    message: "\(name): process README has `## Quick Start` (forbidden)"
                )
            )
        }
        let lineCount = splitLines(content).count
        if lineCount > 80 {
            findings.append(
                Finding(
                    repository: repository,
                    rule: "README-138",
                    message: "\(name): process README is \(lineCount) lines (>80 suggests "
                        + "content should relocate per [README-138])"
                )
            )
        }
        return findings
    }

    static func familyF(
        _ repository: GitHub_Standard::GitHub.Repository.Slug,
        name: String,
        content: String
    ) -> [Institute.CI.Validation.Finding] {
        typealias Finding = Institute.CI.Validation.Finding
        var findings: [Finding] = []
        let extraH2 = splitLines(content).filter {
            h2Line.firstMatch(in: String($0)) != nil && !$0.contains("## License")
        }
        if let first = extraH2.first {
            findings.append(
                Finding(
                    repository: repository,
                    rule: "README-150",
                    message: "\(name): Family F README has extra ## sections "
                        + "(first: \(Institute.CI.Validation.Retired.quoted(prefix(first, 60)))); "
                        + "should be H1 + status blockquote only"
                )
            )
        }
        if let match = statusLine.firstMatch(in: content),
            let status = match.groups[1]?.trimmedWhitespace,
            !statusValues.contains(status)
        {
            findings.append(
                Finding(
                    repository: repository,
                    rule: "README-151",
                    message:
                        "\(name): Family F status \(Institute.CI.Validation.Retired.quoted(status)) "
                        + "not in canonical set \(Institute.CI.Validation.Retired.list(statusValues.sorted()))"
                )
            )
        }
        return findings
    }

    static func familyG(
        _ repository: GitHub_Standard::GitHub.Repository.Slug,
        name: String,
        content: String
    ) -> [Institute.CI.Validation.Finding] {
        guard repository.description != "\(Institute.Organization.`swift-institute`.rawValue)/.github" else {
            return []
        }
        typealias Finding = Institute.CI.Validation.Finding
        var findings: [Finding] = []
        for line in splitLines(content) where h2OrDeeper.firstMatch(in: String(line)) != nil {
            let heading = String(line).trimmedWhitespace
            guard heading != "## Start here" else { continue }
            findings.append(
                Finding(
                    repository: repository,
                    rule: "README-117",
                    message: "\(name): contains section "
                        + Institute.CI.Validation.Retired.quoted(heading)
                        + "; a profile's only section is `## Start here`"
                )
            )
        }
        if content.contains("```") {
            findings.append(
                Finding(
                    repository: repository,
                    rule: "README-117",
                    message: "\(name): contains a code block"
                )
            )
        }
        return findings
    }
}
