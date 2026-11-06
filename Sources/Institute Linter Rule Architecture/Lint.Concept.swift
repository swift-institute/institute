public import Lint

extension Lint {
    /// The concept map (coenttb/work#239): which type owns a concept, so the rules can tell a raw value or a second
    /// implementation from the owner's. A name here is only a candidate: a value that really is something else, such as
    /// a URL's path, keeps its `String` under a suppression that says so.
    public enum Concept {}
}

extension Lint.Concept {
    /// A parameter or property name, lowercased, and the type that owns what it holds.
    package static let values: [Swift::String: Swift::String] = [
        "path": "File.Path",
        "filepath": "File.Path",
        "directory": "File.Directory",
        "folder": "File.Directory",
        "iban": "ISO_13616.IBAN",
        "url": "RFC_3986.URI",
        "href": "RFC_3986.URI",
        "digest": "FIPS_180_4.Digest",
        "sha256": "FIPS_180_4.Digest",
        "email": "EmailAddress",
        "uuid": "RFC_4122.UUID",
        "language": "RFC_5646.LanguageTag",
        "lang": "RFC_5646.LanguageTag",
        "country": "ISO_3166.Code",
        "date": "ISO_8601.CalendarDate",
        "timestamp": "RFC_3339.DateTime",
        "host": "RFC_3986.URI.Host",
        "domain": "Domain",
        "mimetype": "RFC_9110.MediaType",
        "mediatype": "RFC_9110.MediaType",
        "contenttype": "RFC_9110.MediaType",
        "version": "Version",
    ]

    /// A top-level type name and the target that owns it.
    package static let types: [Swift::String: Swift::String] = [
        "Path": "Path",
        "Keychain": "Keychain Security",
    ]

    /// A framework function that only its owner may call, and that owner.
    package static let functions: [Swift::String: Swift::String] = [
        "SecItemAdd": "Keychain Security",
        "SecItemCopyMatching": "Keychain Security",
        "SecItemDelete": "Keychain Security",
        "SecItemUpdate": "Keychain Security",
    ]

    /// A concept apps hold in a stand-in, and the owner the stand-in moves to. Phase 6 of coenttb/work#239 replaces each and
    /// removes its entry; that phase is done when this is empty.
    package static let interim: [Swift::String: Swift::String] = [
        "Ledger.Day": "ISO_8601.CalendarDate",
        "Reader.Date": "ISO_8601.CalendarDate.Reduced",
    ]

    /// Target suffixes that are leaves: SQL rows, schemas, command-line arguments and integrations with other types.
    package static let leaves: [Swift::String] = [" SQL", " Schema", " Command", " CLI", " MCP", " Integration"]

    package static func isLeaf(_ filePath: Swift::String) -> Swift::Bool {
        guard let target = target(of: filePath) else { return true }
        return Self.leaves.contains { target.hasSuffix($0) }
    }

    /// The main target `filePath` is in; nil for a test, a manifest or anything outside `Sources`.
    package static func target(of filePath: Swift::String) -> Swift::String? {
        let directories = filePath.split(separator: "/", omittingEmptySubsequences: true).dropLast()
        guard let anchor = directories.lastIndex(of: "Sources"), anchor + 1 < directories.endIndex else { return nil }
        guard !directories.contains("Tests") else { return nil }
        return Swift::String(directories[anchor + 1])
    }
}

extension Lint.Concept {
    /// Each package's ratchet: how many `raw concept` and `concept parallel` findings it may have. A package not listed
    /// may have none. A ceiling may fall and never rise, so a rise shows here, in one reviewed place.
    public static let ceilings: [Swift::String: Swift::Int] = [
        "affairs": 13,
        "coenttb-cli": 1,
        "database": 20,
        "reader": 6,
        "snuffel": 6,
        "swift-licensing": 1,
        "swift-processes": 4,
    ]

    public static let rules: Swift::Set<Swift::String> = ["raw concept", "concept parallel"]

    /// Why `package` fails the ratchet with `findings` findings; nil when it holds.
    public static func overrun(package: Swift::String, findings: Swift::Int) -> Swift::String? {
        let ceiling = Self.ceilings[package] ?? 0
        guard findings > ceiling else { return nil }
        return "concept ratchet: \(package) has \(findings) findings of \(ceiling) allowed. Fix them; a ceiling never rises."
    }
}
