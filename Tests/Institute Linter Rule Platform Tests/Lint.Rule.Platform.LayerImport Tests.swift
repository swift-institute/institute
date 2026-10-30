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
    struct `platform layer import Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct `Platform-stack carve-out` {}
        @Suite struct `Scope gates` {}
    }
}

extension Lint.Rule.`platform layer import Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`platform layer import`.observe(parsed, .warning).findings
    }

    /// The eight forbidden modules, verbatim from the Python's
    /// `PLATFORM_IMPORT_FORBIDDEN` mapping.
    static let forbiddenModules: [String] = [
        "Darwin_Kernel_Standard",
        "Linux_Kernel_Standard",
        "Windows_32_Core",
        "ISO_9945_Core",
        "Darwin_Kernel",
        "Linux_Kernel",
        "Windows_Kernel",
        "POSIX_Kernel",
    ]
}

extension Lint.Rule.`platform layer import Tests`.Unit {
    @Test
    func `every forbidden L2-spec and L3-policy module is flagged`() {
        for module in Lint.Rule.`platform layer import Tests`.forbiddenModules {
            let findings = Lint.Rule.`platform layer import Tests`.findings(
                in: "import \(module)",
                file: "Sources/Consumer/Client.swift"
            )
            #expect(findings.count == 1, "expected a finding for import \(module)")
        }
    }

    @Test
    func `a bare forbidden import carries the rule identity and severity`() {
        let findings = Lint.Rule.`platform layer import Tests`.findings(
            in: "import POSIX_Kernel",
            file: "Sources/Consumer/Client.swift"
        )
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "platform layer import")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `access-modified and exported import shapes are flagged`() {
        for source in [
            "public import Darwin_Kernel",
            "internal import Darwin_Kernel",
            "@_exported public import Darwin_Kernel",
            "@_exported import Darwin_Kernel",
        ] {
            let findings = Lint.Rule.`platform layer import Tests`.findings(
                in: source,
                file: "Sources/Consumer/Client.swift"
            )
            #expect(findings.count == 1, "expected a finding for \(source)")
        }
    }

    @Test
    func `a submodule import of a forbidden module is flagged`() {
        // The first path component pulls in the module; the Python's regex
        // captures exactly that leading identifier.
        let findings = Lint.Rule.`platform layer import Tests`.findings(
            in: "import Darwin_Kernel_Standard.Something",
            file: "Sources/Consumer/Client.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `a forbidden import guarded by a platform conditional is still flagged`() {
        // Grep granularity in the Python: `#if` nesting does not exempt.
        let source = """
            #if os(macOS)
            import Darwin_Kernel
            #endif
            """
        let findings = Lint.Rule.`platform layer import Tests`.findings(
            in: source,
            file: "Sources/Consumer/Client.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `repeated imports of one module collapse to one finding per file`() {
        // The Python de-duplicates on the (module, file) pair.
        let source = """
            import POSIX_Kernel
            #if os(Linux)
            import POSIX_Kernel
            #endif
            """
        let findings = Lint.Rule.`platform layer import Tests`.findings(
            in: source,
            file: "Sources/Consumer/Client.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `distinct forbidden modules each get their own finding`() {
        let source = """
            import Darwin_Kernel
            import Linux_Kernel
            import Windows_Kernel
            """
        let findings = Lint.Rule.`platform layer import Tests`.findings(
            in: source,
            file: "Sources/Consumer/Client.swift"
        )
        #expect(findings.count == 3)
    }
}

extension Lint.Rule.`platform layer import Tests`.`Edge Case` {
    @Test
    func `the L3-unifier surface is NOT flagged`() {
        // This is the sanctioned consumer shape the rule exists to steer to.
        let source = """
            import Kernel
            import IO
            import Paths
            """
        let findings = Lint.Rule.`platform layer import Tests`.findings(
            in: source,
            file: "Sources/Consumer/Client.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `raw C-library and stdlib imports are NOT flagged`() {
        // [PLAT-ARCH-008j]'s raw-import ban is a different validator's rule
        // (validate-platform-architecture.py); this rule mirrors only
        // validate-layer-deps.py and must not annex it.
        let source = """
            import Darwin
            import Glibc
            import WinSDK
            import Swift
            """
        let findings = Lint.Rule.`platform layer import Tests`.findings(
            in: source,
            file: "Sources/Consumer/Client.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a module merely PREFIXED by a forbidden name is NOT flagged`() {
        // Exact match on the first path component, not a prefix test.
        let source = """
            import POSIX_Kernel_Helpers
            import Darwin_Kernel_StandardKit
            """
        let findings = Lint.Rule.`platform layer import Tests`.findings(
            in: source,
            file: "Sources/Consumer/Client.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `empty source produces no findings`() {
        let findings = Lint.Rule.`platform layer import Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }

    @Test
    func `the default no-directory path still fires`() {
        // `test.swift` has no directory segment; no gate may swallow it, or
        // an accidentally rootless run goes silently green.
        let findings = Lint.Rule.`platform layer import Tests`.findings(in: "import POSIX_Kernel")
        #expect(findings.count == 1)
    }
}

// The platform stack itself is exempt — it exists precisely so the rest of
// the ecosystem doesn't need these imports. Controlled in both directions:
// an over-skip is as bad as a never-fire.
extension Lint.Rule.`platform layer import Tests`.`Platform-stack carve-out` {
    // MARK: - Negative controls (inside the stack → must NOT fire)

    @Test
    func `every registry package is exempt`() {
        for package in [
            // L1 platform-aware primitives
            "swift-kernel", "swift-cpu", "swift-darwin",
            "swift-linux", "swift-windows",
            // L2 spec (including the historical swift-windows-standard name)
            "swift-iso-9945", "swift-darwin-standard", "swift-linux-standard",
            "swift-windows-32", "swift-windows-standard",
            // L3-policy
            "swift-posix", "swift-darwin", "swift-linux", "swift-windows",
            // L3-unifier
            "swift-kernel", "swift-strings", "swift-paths", "swift-ascii",
            "swift-systems", "swift-io", "swift-threads", "swift-environment",
            // L3-domain
            "swift-file-system",
        ] {
            let findings = Lint.Rule.`platform layer import Tests`.findings(
                in: "import Darwin_Kernel_Standard",
                file: "\(package)/Sources/Some Target/File.swift"
            )
            #expect(findings.isEmpty, "expected no finding inside \(package)")
        }
    }

    @Test
    func `a deeper checkout prefix before the stack package is still exempt`() {
        let findings = Lint.Rule.`platform layer import Tests`.findings(
            in: "import POSIX_Kernel",
            file:
                "checkouts/swift-institute/swift-compositions/swift-kernel/Sources/Kernel/File.swift"
        )
        #expect(findings.isEmpty)
    }

    // MARK: - Over-skip guards (look-alikes → must STILL fire)

    @Test
    func `a look-alike package name is NOT exempted`() {
        // Whole-segment match only: neither a superstring package name nor a
        // name merely containing a registry token qualifies.
        for path in [
            "swift-kernel-tools/Sources/Tools/File.swift",
            "swift-posix-extras/Sources/Extras/File.swift",
            "my-swift-darwin/Sources/Lib/File.swift",
        ] {
            let findings = Lint.Rule.`platform layer import Tests`.findings(
                in: "import POSIX_Kernel",
                file: path
            )
            #expect(findings.count == 1, "expected a finding for \(path)")
        }
    }

    @Test
    func `a FILE named after a stack package is NOT exempted`() {
        // Only directory segments qualify; the trailing filename is dropped.
        let findings = Lint.Rule.`platform layer import Tests`.findings(
            in: "import POSIX_Kernel",
            file: "Sources/Consumer/swift-posix.swift"
        )
        #expect(findings.count == 1)
    }
}

// The Python walks `Sources/` only; test/experiment/example trees, package
// manifests and hidden directories are never inspected. Controlled in both
// directions.
extension Lint.Rule.`platform layer import Tests`.`Scope gates` {
    // MARK: - Negative controls (outside the Python's scan → must NOT fire)

    @Test
    func `Tests, Experiments and Examples roots are NOT flagged`() {
        for path in [
            "Tests/Consumer Tests/Client Tests.swift",
            "Experiments/Spike/Probe.swift",
            "Examples/Demo/main.swift",
        ] {
            let findings = Lint.Rule.`platform layer import Tests`.findings(
                in: "import Darwin_Kernel",
                file: path
            )
            #expect(findings.isEmpty, "expected no finding for \(path)")
        }
    }

    @Test
    func `a package manifest is NOT flagged`() {
        for path in ["Package.swift", "Package@swift-6.0.swift", "Nested/Package.swift"] {
            let findings = Lint.Rule.`platform layer import Tests`.findings(
                in: "import POSIX_Kernel",
                file: path
            )
            #expect(findings.isEmpty, "expected no finding for \(path)")
        }
    }

    @Test
    func `a hidden directory segment is NOT flagged`() {
        let findings = Lint.Rule.`platform layer import Tests`.findings(
            in: "import POSIX_Kernel",
            file: ".build/checkouts/dep/Sources/Lib/File.swift"
        )
        #expect(findings.isEmpty)
    }

    // MARK: - Over-skip guards (coincidental look-alikes → must STILL fire)

    @Test
    func `main-target dirs merely CONTAINING gate names still fire`() {
        for path in [
            "Sources/TestKit/Helper.swift",
            "Sources/Consumer/Tests.swift",
            "Sources/Consumer/PackageInfo.swift",
        ] {
            let findings = Lint.Rule.`platform layer import Tests`.findings(
                in: "import POSIX_Kernel",
                file: path
            )
            #expect(findings.count == 1, "expected a finding for \(path)")
        }
    }
}
