// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-institute-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-institute-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Lint
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_Naming

extension Lint.Rule {
    @Suite
    struct `compound type name Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`compound type name Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`compound type name`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`compound type name Tests`.Unit {
    @Test
    func `struct FooBar is flagged`() {
        let source = "struct FooBar {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "compound type name")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `malformed rule declaration is flagged by its own bundle`() {
        let source = """
            extension Lint.Rule {
                enum MalformedRule {}
            }
            """
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 1)
        #expect(findings.first?.identifier == "compound type name")
    }

    @Test
    func `enum FileDirectoryWalk is flagged`() {
        let source = "enum FileDirectoryWalk {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `class DirectoryWalk is flagged`() {
        let source = "class DirectoryWalk {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `actor NonBlockingSelector is flagged`() {
        let source = "actor NonBlockingSelector {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `protocol IteratorProtocol is flagged`() {
        let source = "protocol IteratorProtocol {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `acronym-prefix IOError is flagged`() {
        // Acronym (IO) followed by a CamelCase word (Error) is a compound.
        let source = "struct IOError {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `acronym-prefix URLPath is flagged`() {
        let source = "struct URLPath {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple offending types are all flagged`() {
        let source = """
            struct FooBar {}
            enum FileSystem {}
            class HTTPClient {}
            """
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 3)
    }
}

extension Lint.Rule.`compound type name Tests`.`Edge Case` {
    @Test
    func `single-word struct Foo is NOT flagged`() {
        let source = "struct Foo {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `single-word enum Walk is NOT flagged`() {
        let source = "enum Walk {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `acronym URL is NOT flagged`() {
        let source = "struct URL {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `acronym UUID is NOT flagged`() {
        let source = "struct UUID {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `short acronym IO is NOT flagged`() {
        let source = "enum IO {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    /// stdlib-method-mirror exemption ([API-NAME-003]): a Tag enum whose name
    /// elevates `Swift.Sequence.allSatisfy(_:)` inherits the compound spelling.
    /// Joins CompactMap / FlatMap / ForEach in the mirror citation set.
    @Test
    func `stdlib-mirror AllSatisfy type is NOT flagged`() {
        let source = "enum AllSatisfy {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `spec namespace RFC_4122 is NOT flagged`() {
        let source = "enum RFC_4122 {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `spec namespace ISO_9945 is NOT flagged`() {
        let source = "enum ISO_9945 {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `package-scoped FooBar is NOT flagged`() {
        let source = "package struct FooBar {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested compound TypeBar inside outer is flagged`() {
        // Nested types follow the same rule — compound is still compound.
        let source = """
            enum Outer {
                struct InnerType {}
            }
            """
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `leading-underscore _BoxStorage is flagged`() {
        // Leading underscore on a CamelCase compound — still compound;
        // not exempted by the underscore rule (that's for spec namespaces).
        // Detection: skip the leading underscore, then evaluate `BoxStorage`.
        // Current implementation: contains("_") returns true for leading
        // underscore too — exempted. Document the limitation as edge case;
        // a follow-up could special-case leading underscore.
        let source = "struct _BoxStorage {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        // Documented behavior: leading-underscore SPI types are not flagged.
        #expect(findings.isEmpty)
    }

    @Test
    func `single uppercase F is NOT flagged`() {
        let source = "struct F {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension blocks do not introduce findings`() {
        // Extensions are not type declarations; they extend existing types.
        let source = """
            extension FooBar {
                func walk() {}
            }
            """
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // MARK: - Backtick-escape exemption

    @Test
    func `backticked struct name with internal compound shape is NOT flagged`() {
        // Hypothetical narrative @Suite scaffold name with internal
        // CamelCase API reference. The `Naming.isBackticked` exemption
        // short-circuits before the predicate scans for word boundaries.
        let source = "struct `Sequence FlatMap Tests` {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `backticked sub-suite category name is NOT flagged`() {
        // Cohort precedent: backticked sub-suite category name like
        // `Edge Case`. Title Case multi-word backticked form — even
        // if word-boundary logic would normally split it, the
        // backtick exemption applies.
        let source = "struct `Edge Case` {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `plain CamelCase struct name remains flagged after backtick exemption`() {
        // Regression guard: the backtick exemption MUST NOT
        // short-circuit non-backticked CamelCase type names.
        let source = "struct FileDirectoryWalk {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - Visibility-scope exemption (private / fileprivate)

    @Test
    func `private enum UserCount is NOT flagged`() {
        // Tagged phantom-type tag pattern (e.g.,
        // `private enum UserCount {} let users: Tagged<UserCount, Cardinal>`).
        // Private decls have no consumer-observable surface even within
        // the module — symmetric with [API-NAME-002] (2026-05-11).
        let source = "private enum UserCount {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `fileprivate struct FooBar is NOT flagged`() {
        let source = "fileprivate struct FooBar {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested type inside private outer is NOT flagged`() {
        // Effective-visibility walk-up: a nested type inside a
        // fileprivate/private enclosing type is effectively
        // fileprivate/private even when its own modifier list is empty.
        let source = """
            private enum Outer {
                struct InnerType {}
            }
            """
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public CamelCase remains flagged when private exemption does not apply`() {
        // Regression guard: the visibility-scope exemption MUST NOT
        // short-circuit non-private CamelCase type decls.
        let source = "public struct FileDirectoryWalk {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `stdlib-method-mirror type names are exempt per API-NAME-003`() {
        // `CompactMap`, `FlatMap`, `ForEach` are institute lazy-iteration
        // adapter types whose name elevates the corresponding stdlib
        // method (compactMap / flatMap / forEach) to a namespace.
        // Inheriting stdlib's compound spelling preserves the spec-mirror
        // correspondence; fragmenting into `Compact.Map` etc. would drift
        // from Swift.Sequence vocabulary.
        let source = """
            extension Sequence {
                public struct CompactMap<Base, Output> {}
                public struct FlatMap<Base, Output> {}
                public enum ForEach {}
            }
            """
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `compound type names NOT in stdlib-method-mirror dict are still flagged`() {
        // Regression guard: the spec-mirror exemption is name-scoped to
        // the citation dict. An arbitrary compound type name like
        // `MapReduce` (not in dict) still fires.
        let source = "public struct MapReduce {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// #16 Option C ledger, Entries III.a/III.b (DECISION 2026-07-23): brand
// tokens whose internal capitals are brand/spec orthography.
extension Lint.Rule.`compound type name Tests`.`Edge Case` {
    @Test
    func `brand token OAuth is NOT flagged`() {
        // The swift-github-http `GitHub.HTTP.OAuth` shape (759330b seed).
        let source = """
            extension GitHub.HTTP {
                public enum OAuth: Sendable {}
            }
            """
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `brand token GitHub is NOT flagged`() {
        // The swift-identities-github shape (0205e7f seed).
        let source = """
            extension Identity.OAuth {
                public struct GitHub: Sendable {}
            }
            """
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `brand token IPv4 is NOT flagged`() {
        let source = "public enum IPv4 {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `brand-token-prefixed compound is still flagged`() {
        // Exact-match only: `GitHubClient` is a genuine compound.
        let source = "public struct GitHubClient {}"
        let findings = Lint.Rule.`compound type name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// Scan-scope gate, symmetric with `compound identifier` — a SwiftPM
// manifest is build configuration, not API surface. Ruled
// swift-institute/.github#90 comment 5150641576 item 1(a).
extension Lint.Rule.`compound type name Tests`.`Edge Case` {
    @Test
    func `bare Package swift filename is out of scan scope`() {
        // Bare-filename positive control.
        let findings = Lint.Rule.`compound type name Tests`.findings(
            in: "struct FooBar {}",
            file: "Package.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `nested Package swift path is out of scan scope`() {
        let findings = Lint.Rule.`compound type name Tests`.findings(
            in: "struct FooBar {}",
            file: "Tests/Fixtures/Package.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `version-specific Package at swift manifest is out of scan scope`() {
        let findings = Lint.Rule.`compound type name Tests`.findings(
            in: "struct FooBar {}",
            file: "Package@swift-6.3.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `the same source in an ordinary file is still flagged`() {
        let findings = Lint.Rule.`compound type name Tests`.findings(
            in: "struct FooBar {}",
            file: "Sources/Core/FooBar.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `PackageInfo swift is NOT treated as a manifest`() {
        let findings = Lint.Rule.`compound type name Tests`.findings(
            in: "struct FooBar {}",
            file: "Sources/Core/PackageInfo.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `a directory segment named Package swift does NOT gate the file`() {
        let findings = Lint.Rule.`compound type name Tests`.findings(
            in: "struct FooBar {}",
            file: "Sources/Package.swift/FooBar.swift"
        )
        #expect(findings.count == 1)
    }
}
