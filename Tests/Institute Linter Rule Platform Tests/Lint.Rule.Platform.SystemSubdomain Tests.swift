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

@testable import Institute_Linter_Rule_Platform

extension Lint.Rule {
    @Suite
    struct `system subdomain Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`system subdomain Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`system subdomain`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`system subdomain Tests`.Unit {
    @Test
    func `extension Darwin dot System is flagged`() {
        let source = """
            extension Darwin.System {
                public static func op() {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "system subdomain")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `extension Linux with nested enum System is flagged`() {
        let source = """
            extension Linux {
                public enum System {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `enum Windows with nested enum System is flagged`() {
        let source = """
            public enum Windows {
                public enum System {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `both extension forms in one file flagged twice`() {
        let source = """
            extension Darwin.System {}
            extension Linux.System {}
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    // #21 defect 10: the nested-`System` check was previously wired only
    // to the `EnumDeclSyntax` visit, even though `struct` / `class` /
    // `actor` fed the same `nameStack`.

    @Test
    func `extension Darwin with nested struct System is flagged`() {
        let source = """
            extension Darwin {
                public struct System {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension Linux with nested class System is flagged`() {
        let source = """
            extension Linux {
                public class System {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension Windows with nested actor System is flagged`() {
        let source = """
            extension Windows {
                public actor System {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `deeply qualified extension Darwin dot Kernel dot System is flagged`() {
        let source = """
            extension Darwin.Kernel.System {
                public static func op() {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension Android with nested enum System is flagged`() {
        let source = """
            extension Android {
                public enum System {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`system subdomain Tests`.`Edge Case` {
    @Test
    func `extension System is NOT flagged`() {
        let source = """
            extension System {
                public static func op() {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension Darwin with non-System subdomain is NOT flagged`() {
        let source = """
            extension Darwin {
                public enum Kernel {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `file-scope enum System is NOT flagged`() {
        let source = """
            public enum System {
                public static func op() {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-platform parent with enum System is NOT flagged`() {
        let source = """
            public enum Foo {
                public enum System {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension Darwin dot Kernel is NOT flagged`() {
        let source = """
            extension Darwin.Kernel {
                public static func op() {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`system subdomain Tests`.`Edge Case` {
    @Test
    func `the file system domain under a platform is NOT flagged`() {
        let source = """
            extension Windows.`32`.Kernel.File.System {
                public enum Stats: Sendable {}
            }
            """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
