import GitHub_Standard
public import Institute_CI_Model
public import Institute_Model

import struct Swift.String

extension Institute.CI.Validation {
    /// `[CI-004b]` — a per-authority sub-org `.github` repository must not
    /// host a `swift-ci.yml` wrapper.
    ///
    /// The reason is a hard platform limit, not taste: GitHub Actions caps
    /// a `workflow_call` chain at four levels, and a sub-org wrapper would
    /// insert a fifth hop that breaks the universal's six advisory linter
    /// sub-dispatches. Per-authority concerns belong in the universal
    /// `swift-ci.yml` as advisory jobs filtered by repository-name
    /// pattern.
    ///
    /// The rule sunsets when GitHub raises the chain limit or the
    /// universal inlines its advisory linters — neither has happened.
    public struct SubOrgWrappers: Validator {
        public let rules: [Rule] = ["CI-004b"]
        public let retiredScript: String? = ".github/scripts/validate-sub-org-wrappers.py"

        public init() {}

        /// The eleven L2 authority sub-orgs, which route through the
        /// `swift-standards` layer wrapper.
        /// The organizations nested under the swift-standards layer root:
        /// the specification authorities and vendors `fleet.json` places at L3.
        public static let subOrganizations: Set<String> = [
            "swift-ietf", "swift-iso", "swift-w3c", "swift-whatwg", "swift-ecma",
            "swift-incits", "swift-ieee", "swift-iec", "swift-arm-ltd",
            "swift-intel", "swift-riscv", "swift-linux-foundation", "swift-microsoft",
            "swift-bipm",
        ]

        public func findings(in subject: Subject) throws(EnvironmentDefect) -> [Finding] {
            guard let organization = try Self.subOrganization(of: subject) else {
                return []  // not a sub-org `.github` repository — out of scope
            }
            guard try subject.text(at: ".github/workflows/swift-ci.yml") != nil else {
                return []  // the canonical state: no wrapper exists
            }
            return [
                Finding(
                    repository: subject.repository,
                    rule: rules[0],
                    message: Self.message(organization: organization)
                )
            ]
        }

        /// The sub-org this invocation targets, or `nil`.
        ///
        /// Production reads the `<org>/.github` coordinate. A
        /// `.github-as-sub-org` marker at the subject root overrides it,
        /// because the fixture harness reports every scenario as
        /// `swift-institute-test/<name>` — an owner no production sweep
        /// passes — and the sub-org branch would otherwise be unreachable
        /// from the corpus.
        static func subOrganization(of subject: Subject) throws(EnvironmentDefect) -> String? {
            if let marker = try subject.text(at: ".github-as-sub-org") {
                let named = marker.trimmingWhitespace
                return subOrganizations.contains(named) ? named : nil
            }
            let parts = subject.repository.split(separator: "/", maxSplits: 1)
            guard parts.count == 2, parts[1] == ".github",
                subOrganizations.contains(String(parts[0]))
            else { return nil }
            return String(parts[0])
        }

        static func message(organization: String) -> String {
            """
            .github/workflows/swift-ci.yml EXISTS at sub-org \
            `\(organization)/.github` — per [CI-004b] sub-org wrappers MUST NOT \
            be created (GitHub Actions `workflow_call` 4-level chain limit would \
            break the universal's advisory linter sub-dispatches). This sub-org's \
            packages call `swift-institute/.github/.github/workflows/swift-ci.yml@main` \
            directly, like every package. Per-authority concerns belong in the \
            universal `swift-ci.yml` as advisory jobs filtered by repo-name pattern, \
            not as a per-authority wrapper.
            """
        }
    }
}

extension String {
    /// Leading and trailing ASCII whitespace removed — `str.strip()`, which
    /// the retired scripts used on every marker file they read.
    ///
    /// `fileprivate` on purpose: `CI Validation` is the one target the
    /// whole port fleet adds files to concurrently, and a target-internal
    /// helper on a stdlib type is exactly the shape two peers collide on.
    fileprivate var trimmingWhitespace: String {
        var value = Substring(self)
        while let first = value.first, first.isWhitespace { value = value.dropFirst() }
        while let last = value.last, last.isWhitespace { value = value.dropLast() }
        return String(value)
    }
}
