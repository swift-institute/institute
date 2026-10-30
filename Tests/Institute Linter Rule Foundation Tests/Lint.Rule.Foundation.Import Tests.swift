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

@testable import Institute_Linter_Rule_Foundation

extension Lint.Rule {
    @Suite
    struct `foundation import Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`foundation import Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`foundation import`.observe(parsed, .warning).findings
    }

    @Suite struct `Foundation Integration carve-out` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
    @Suite struct `House convention soundness` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

// Soundness probe against the two house conventions that defeat hand-rolled
// patterns: umbrella `exports.swift` files carrying the imports, and
// space-separated target directories. A grep-based probe reported a package
// Foundation-free on 2026-07-24 for the wrong reason — every import lived in
// an umbrella file its pattern could not see, on a rule being ratcheted to
// `.error`. These establish whether the RULE shares that blind spot.
//
// EVERY case here is a positive control: each MUST fire. A zero anywhere in
// this suite is the finding.
extension Lint.Rule.`foundation import Tests`.`House convention soundness` {
    @Test
    func `@_exported public import Foundation is flagged`() {
        // The combined form: attribute AND access modifier on one line. Neither
        // `public import` nor `@_exported import` alone covers it, and a
        // character-class pattern like `@[a-zA-Z]+` cannot match `@_exported`
        // at all — the underscore is outside the class.
        let source = "@_exported public import Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `@_exported public import of every family member is flagged`() {
        for module in [
            "Foundation", "FoundationEssentials", "FoundationNetworking", "FoundationXML",
        ] {
            let findings = Lint.Rule.`foundation import Tests`.findings(
                in: "@_exported public import \(module)"
            )
            #expect(
                findings.count == 1,
                "expected a finding for @_exported public import \(module)"
            )
        }
    }

    @Test
    func `an umbrella exports file in a SPACE-SEPARATED target directory is flagged`() {
        // Both conventions at once — the shape that defeated the grep. The path
        // carries a space, and every import is an `@_exported public import` in
        // an umbrella file rather than in ordinary sources.
        let source = """
            @_exported public import Foundation
            @_exported public import FoundationNetworking
            @_exported public import Time
            @_exported public import Binary
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Sources/Products Live/exports.swift"
        )
        #expect(findings.count == 2)
    }

    @Test
    func `a space-separated MAIN target directory is not accidentally exempted`() {
        // The three path gates added 2026-07-25 split on "/" — a directory name
        // containing spaces must not resemble an exempt segment. `Products Live`
        // is core code and must fire.
        let source = "import Foundation"
        for path in [
            "Sources/Products Live/Client.swift",
            "Sources/Stripe Balance Types/Model.swift",
            "Sources/Products Live/exports.swift",
        ] {
            let findings = Lint.Rule.`foundation import Tests`.findings(in: source, file: path)
            #expect(findings.count == 1, "expected a finding for \(path)")
        }
    }

    @Test
    func `an umbrella file mixing exempt and family imports flags only the family`() {
        let source = """
            @_exported public import Time
            @_exported public import HTML_Foundation
            @_exported public import FoundationXML
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Sources/Products Live/exports.swift"
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`foundation import Tests`.Unit {
    @Test
    func `bare Foundation import is flagged`() {
        let source = "import Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "foundation import")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `FoundationEssentials import is flagged`() {
        let source = "import FoundationEssentials"
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Foundation submodule import is flagged`() {
        let source = "import Foundation.NSURL"
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Foundation alongside other imports flags only Foundation`() {
        let source = """
            import Time
            import Foundation
            import Binary
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public import of Foundation is flagged`() {
        let source = "public import Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `FoundationNetworking import is flagged`() {
        // FoundationNetworking is where URLSession lives on Linux. Omitting it
        // left the rule blind on exactly the axis it exists to guard.
        let source = "import FoundationNetworking"
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `exported import of FoundationNetworking is flagged`() {
        // The live shape that motivated closing the hole: a package re-exporting
        // FoundationNetworking to every consumer while passing the rule clean.
        // Observed at swift-urlrequest-handler exports.swift:4 on 2026-07-24.
        let source = "@_exported import FoundationNetworking"
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `FoundationNetworking guarded by canImport is still flagged`() {
        // The conditional does not make the import Foundation-free; it only makes
        // it platform-conditional. Observed shape at DefaultSessionKey.swift:11-13.
        let source = """
            #if canImport(FoundationNetworking)
                import FoundationNetworking
            #endif
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `FoundationXML import is flagged`() {
        let source = "import FoundationXML"
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `every Foundation family member is flagged exactly once`() {
        let source = """
            import Foundation
            import FoundationEssentials
            import FoundationNetworking
            import FoundationXML
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.count == 4)
    }
}

extension Lint.Rule.`foundation import Tests`.`Edge Case` {
    @Test
    func `institute primitives imports are NOT flagged`() {
        let source = """
            import Time
            import Binary
            import Cardinal
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Swift stdlib imports are NOT flagged`() {
        let source = """
            import Swift
            import Synchronization
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `module with Foundation in name (not Foundation framework) is NOT flagged`() {
        // A package named e.g. swift-html-foundation would be imported as
        // Html_Foundation — not the Apple Foundation framework. Only the
        // first path component is checked.
        let source = "import HTML_Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `empty source produces no findings`() {
        let source = ""
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `family name in a non-leading position is NOT flagged`() {
        // Widening the family must not widen the non-leading-component exemption.
        // Server_Foundation is an institute package, not the Apple framework.
        let source = """
            import HTML_Foundation
            import Server_Foundation
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `a longer module name merely PREFIXED by a family member is NOT flagged`() {
        // The match is exact on the first path component, not a prefix test.
        // FoundationNetworkingHelpers is a different module from
        // FoundationNetworking and must not be flagged by widening the family.
        let source = """
            import FoundationNetworkingHelpers
            import FoundationalTypes
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `FoundationNetworking submodule import is flagged`() {
        let source = "import FoundationNetworking.NSURLSession"
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// The dedicated, opt-in `* Foundation Integration` subtarget is the
// sanctioned Foundation boundary ([PRIM-FOUND-001]); a file inside one must
// NOT fire, while every core target at every layer STILL fires. Controlled
// in both directions — an over-skip is as bad as a never-fire. Real target
// dir names verified 2026-07-25: swift-json `JSON Foundation Integration`,
// swift-structured-queries
// `Structured Queries Foundation Integration`.
extension Lint.Rule.`foundation import Tests`.`Foundation Integration carve-out` {
    // MARK: - Negative controls (inside an FI target → must NOT fire)

    @Test
    func `Foundation import inside an FI target is NOT flagged`() {
        let source = "import Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Sources/JSON Foundation Integration/JSON.Foundation.Coder.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `every Foundation family member inside an FI target is NOT flagged`() {
        let source = """
            import Foundation
            public import Foundation
            @_exported import FoundationNetworking
            import FoundationXML
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Sources/Structured Queries Foundation Integration/Bridge.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `FI target at the source-tree root (no Sources prefix) is NOT flagged`() {
        // The carve-out keys on the directory segment, not on a `Sources/`
        // prefix, so a file located directly under the FI target dir is exempt.
        let source = "import Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "JSON Foundation Integration/exports.swift"
        )
        #expect(findings.isEmpty)
    }

    // MARK: - Positive controls (core targets → must STILL fire)

    @Test
    func `Foundation import in a core target still fires`() {
        let source = "import Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Sources/JSON/JSON.Value.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `every detection shape in a core target still fires`() {
        // Preserves the rule's named detections — bare, public, @_exported
        // FoundationNetworking, FoundationXML — in a NON-FI (core) path.
        let source = """
            import Foundation
            public import Foundation
            @_exported import FoundationNetworking
            import FoundationXML
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Sources/JSON/Core.swift"
        )
        #expect(findings.count == 4)
    }

    @Test
    func `default test path (no directory) still fires`() {
        // The default `file: "test.swift"` has no directory segment; the
        // carve-out must not swallow it, or every existing fixture goes blind.
        let source = "import Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - Over-skip guards (look-alike core dirs → must STILL fire)

    @Test
    func `core target merely named with Foundation still fires`() {
        // `HTML Foundation` is a core institute target, not an FI subtarget —
        // its dir does not end in ` Foundation Integration`, so it must fire.
        let source = "import Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Sources/HTML Foundation/Renderer.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `no-space prefix before Foundation Integration still fires`() {
        // The required leading space means a segment without a real brand-token
        // boundary (`XFoundation Integration`) is not the sanctioned shape.
        let source = "import Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Sources/XFoundation Integration/File.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `filename ending in Foundation Integration inside a core dir still fires`() {
        // Only DIRECTORY segments qualify; a source file whose name ends in
        // `… Foundation Integration.swift` inside a core target is not exempt.
        let source = "import Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Sources/JSON/My Foundation Integration.swift"
        )
        #expect(findings.count == 1)
    }
}

// [ARCH-LAYER-007] governs a package's MAIN targets. Test, experiment and
// example sources ship to no consumer, so firing there was over-reporting.
// Controlled in both directions: the exemption must not leak into `Sources/`
// via a coincidental substring.
extension Lint.Rule.`foundation import Tests`.`Foundation Integration carve-out` {
    // MARK: - Negative controls (non-main targets → must NOT fire)

    @Test
    func `Foundation import in a test target is NOT flagged`() {
        let source = "import Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Tests/JSON Tests/JSON.Value Tests.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `the FI test target is NOT flagged`() {
        // The residual swift-json finding this change closes: an FI *test*
        // target is neither a main target nor a ` Foundation Integration`
        // directory segment, so only the main-target scoping exempts it.
        let source = "import Foundation"
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Tests/JSON Foundation Integration Tests/JSON.Foundation.Coder Tests.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Experiments and Examples roots are NOT flagged`() {
        let source = "@_exported import FoundationNetworking"
        for path in [
            "Experiments/Spike/Probe.swift",
            "Examples/Demo/main.swift",
        ] {
            let findings = Lint.Rule.`foundation import Tests`.findings(in: source, file: path)
            #expect(findings.isEmpty, "expected no finding for \(path)")
        }
    }

    // MARK: - Positive controls (main targets → must STILL fire)

    @Test
    func `every detection shape in a main target still fires after scoping`() {
        let source = """
            import Foundation
            public import Foundation
            @_exported import FoundationNetworking
            import FoundationXML
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Sources/JSON/Core.swift"
        )
        #expect(findings.count == 4)
    }

    // MARK: - Over-skip guards (coincidental substrings → must STILL fire)

    @Test
    func `main-target dirs merely CONTAINING the root names still fire`() {
        // Whole segments only. `TestKit`, `Examples.swift` as a FILE, and a
        // target named `Testing` are main-target code and must not be exempted.
        let source = "import Foundation"
        for path in [
            "Sources/TestKit/Helper.swift",
            "Sources/Testing Support/Helper.swift",
            "Sources/JSON/Examples.swift",
            "Sources/JSON/Tests.swift",
        ] {
            let findings = Lint.Rule.`foundation import Tests`.findings(in: source, file: path)
            #expect(findings.count == 1, "expected a finding for \(path)")
        }
    }

    @Test
    func `default no-directory path still fires after scoping`() {
        // Guards the whole pre-existing fixture suite: if the main-target gate
        // swallowed the bare `test.swift` default, every earlier test would go
        // silently green.
        let findings = Lint.Rule.`foundation import Tests`.findings(in: "import Foundation")
        #expect(findings.count == 1)
    }
}

// A package manifest is not a target: SwiftPM compiles it in its own sandbox
// and ships it to nobody, so it cannot impose Foundation on a consumer. This
// gate is keyed on the FILENAME, unlike the two directory-segment gates, so
// the over-skip guards below are about names rather than path position.
extension Lint.Rule.`foundation import Tests`.`Foundation Integration carve-out` {
    // MARK: - Negative controls (manifests → must NOT fire)

    @Test
    func `a package manifest is NOT flagged`() {
        // The live shape: swift-stripe-types Package.swift:3 imports Foundation
        // (for ProcessInfo-style manifest-time work) and was being counted as
        // shipped Foundation debt.
        let source = """
            // swift-tools-version: 6.3.3
            import Foundation
            import PackageDescription
            """
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: source,
            file: "Package.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a version-specific manifest is NOT flagged`() {
        let source = "import Foundation"
        for path in ["Package@swift-6.0.swift", "Package@swift-5.9.swift"] {
            let findings = Lint.Rule.`foundation import Tests`.findings(in: source, file: path)
            #expect(findings.isEmpty, "expected no finding for \(path)")
        }
    }

    @Test
    func `a nested package's manifest is NOT flagged`() {
        // Keyed on filename precisely so a nested package root is covered; a
        // root-relative test would miss this one.
        let findings = Lint.Rule.`foundation import Tests`.findings(
            in: "import Foundation",
            file: "Tests/Testing/Package.swift"
        )
        #expect(findings.isEmpty)
    }

    // MARK: - Over-skip guards (look-alike names → must STILL fire)

    @Test
    func `source files merely NAMED like a manifest still fire`() {
        // Exact whole-component match. A file that embeds the word, or a source
        // file inside a directory called `Package`, is ordinary main-target code.
        let source = "import Foundation"
        for path in [
            "Sources/JSON/PackageInfo.swift",
            "Sources/JSON/MyPackage.swift",
            "Sources/Package/Registry.swift",
            "Sources/JSON/Package.Description.swift",
        ] {
            let findings = Lint.Rule.`foundation import Tests`.findings(in: source, file: path)
            #expect(findings.count == 1, "expected a finding for \(path)")
        }
    }

    @Test
    func `the manifest gate does not swallow the no-directory default`() {
        // Third time this guard earns its place: each new gate is another chance
        // to blank the entire pre-existing suite without failing anything.
        let findings = Lint.Rule.`foundation import Tests`.findings(in: "import Foundation")
        #expect(findings.count == 1)
    }
}
