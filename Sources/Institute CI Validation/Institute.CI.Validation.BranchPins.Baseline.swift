public import File_System
public import GitHub_Standard
public import Institute_CI_Model
public import Institute_Model
public import Package_Manager

import struct Swift.String

extension Institute.CI.Validation.BranchPins {
    /// The shrink-only burn-down ledger of already-known branch pins.
    ///
    /// A `(repository, dependency URL)` pair in the ledger reports as
    /// `BRANCH-PIN-BASELINE` — informational, never a failure — while
    /// every other pin reports as `BRANCH-PIN-001`. The pair is the key,
    /// not the URL: the same dependency pinned by a *different*
    /// repository is a new pin and must still fire. That near-miss is
    /// one of the retired suite's controls, and it is kept here.
    ///
    /// A missing file is an empty ledger, not a defect. The ledger is an
    /// optional suppression list; its absence means nothing is
    /// suppressed, which fails closed.
    public struct Baseline: Sendable, Equatable {
        /// One suppressed declaration.
        public struct Entry: Sendable, Hashable {
            public let repository: GitHub_Standard::GitHub.Repository.Slug
            public let url: Package.Manifest.Dependency.Location

            public init(repository: GitHub_Standard::GitHub.Repository.Slug, url: Package.Manifest.Dependency.Location) {
                self.repository = repository
                self.url = url
            }
        }

        public static let empty = Self(entries: [])

        public let entries: Set<Entry>

        public init(entries: Set<Entry>) {
            self.entries = entries
        }

        public func suppresses(repository: GitHub_Standard::GitHub.Repository.Slug, url: Package.Manifest.Dependency.Location) -> Bool {
            entries.contains(Entry(repository: repository, url: url))
        }

        /// Read the ledger at `path`; a missing file is `.empty`.
        ///
        /// Lines are `repository<TAB>url`. Blank lines and `#` comments
        /// are ignored, and a line that does not split into exactly two
        /// tab-separated fields, an `owner/name` and a location, is ignored rather than guessed at — a
        /// malformed ledger line must not silently suppress something
        /// adjacent to what it names.
        public static func read(
            at path: File.Path?
        ) throws(Institute.CI.Validation.EnvironmentDefect) -> Self {
            guard let path, Institute.CI.Validation.exists(path.string) else { return .empty }
            guard let text = Institute.CI.Validation.text(at: path.string) else {
                throw .unreadableFile(path: path.string)
            }
            var entries: Set<Entry> = []
            for line in text.split(
                separator: "\n",
                omittingEmptySubsequences: false
            ) {
                let trimmed = line.trimmedWhitespace
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
                let fields = trimmed.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard fields.count == 2,
                    let repository = GitHub_Standard::GitHub.Repository.Slug(fields[0]),
                    let url = Package.Manifest.Dependency.Location(fields[1])
                else { continue }
                entries.insert(Entry(repository: repository, url: url))
            }
            return Self(entries: entries)
        }
    }
}
