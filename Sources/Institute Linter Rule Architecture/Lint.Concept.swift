public import Lint

extension Lint {
    /// The concept map (coenttb/work#239): which type owns a concept, so the rules can tell a raw value or a second
    /// implementation from the owner's. A name here is only a candidate: a value that really is something else, such as
    /// a URL's path, keeps its `String` under a suppression that says so.
    public enum Concept {}
}

extension Lint.Concept {
    /// A concept's word or words, lowercased and run together, and the type that owns what it holds. `owner(of:)`
    /// matches these against the whole words at the end of a name.
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
        "uri": "RFC_3986.URI",
        "link": "RFC_3986.URI",
        "file": "Path",
        "filename": "Path.Component",
        "checksum": "FIPS_180_4.Digest",
        "created": "RFC_3339.DateTime",
        "createdat": "RFC_3339.DateTime",
        "modified": "RFC_3339.DateTime",
        "published": "RFC_3339.DateTime",
        "expires": "RFC_3339.DateTime",
        "currency": "ISO_4217.Code",
        "repository": "GitHub.Repository.Slug",
    ]

    /// Concepts usually held as a number, and their owners. Only these count an integer as raw.
    package static let numbers: [Swift::String: Swift::String] = [
        "port": "RFC_3986.URI.Port"
    ]

    /// Who owns what `name` holds, by the whole words at its end: `documentationURL` is a URL and `originalPath` a path,
    /// while `onHashChange` and `allocation` are neither.
    package static func owner(of name: Swift::String, in concepts: [Swift::String: Swift::String] = values) -> Swift::String? {
        let words = Self.words(of: name)
        for start in words.indices {
            if let owner = concepts[words[start...].joined()] { return owner }
        }
        return nil
    }

    /// The lowercased camelCase words of a name. An acronym is one word, so `URLPath` is `url` and `path`, and digits stay
    /// with the word they follow, so `sha256` is one word.
    package static func words(of name: Swift::String) -> [Swift::String] {
        var words: [Swift::String] = []
        var current = ""
        let characters = Swift::Array(name)
        for (index, character) in characters.enumerated() {
            guard character.isLetter || character.isNumber else {
                if !current.isEmpty { words.append(current.lowercased()) }
                current = ""
                continue
            }
            if character.isUppercase, let previous = current.last {
                let next = index + 1 < characters.endIndex ? characters[index + 1] : nil
                if !previous.isUppercase || next?.isLowercase == true {
                    words.append(current.lowercased())
                    current = ""
                }
            }
            current.append(character)
        }
        if !current.isEmpty { words.append(current.lowercased()) }
        return words
    }

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
    package static let interim: [Swift::String: Swift::String] = [:]

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
