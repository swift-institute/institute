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
    struct `manifest naming grammar Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`manifest naming grammar Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`manifest naming grammar`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`manifest naming grammar Tests`.Unit {
    // Positive control — the known real instance class: the pre-split
    // institute-application head declared concatenated
    // `InstituteArchitecture*` target names (#65's cited fixture pair).
    @Test
    func `concatenated target name is flagged`() {
        let source = """
            let package = Package(
              name: "institute-application",
              targets: [
                .executableTarget(name: "InstituteArchitectureCLI")
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.count == 1)
        #expect(findings.first?.identifier == "manifest naming grammar")
        #expect(findings.first?.message.contains("InstituteArchitectureCLI") == true)
    }

    @Test
    func `concatenated product name is flagged`() {
        let source = """
            let package = Package(
              name: "institute-application",
              products: [
                .library(name: "InstituteApplication", targets: ["Institute Application"])
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non kebab package name is flagged`() {
        for bad in ["SwiftInstitute", "institute_application", "Institute-Application"] {
            let source = """
                let package = Package(name: "\(bad)")
                """
            let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
            #expect(findings.count == 1, "expected slug finding for '\(bad)'")
        }
    }

    @Test
    func `concatenated path segment under a spaced target is flagged`() {
        let source = """
            let package = Package(
              name: "institute-application",
              targets: [
                .target(name: "Institute Application", path: "Sources/InstituteApplication")
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.count == 1)
        #expect(
            findings.first?.message.contains("differs from the target name only by spacing") == true
        )
    }

    // Negative controls — current correct spellings.
    @Test
    func `spaced names and kebab slug are permitted`() {
        let source = """
            let package = Package(
              name: "swift-institute-linter-rules",
              products: [
                .library(name: "Institute Linter Rule Naming", targets: ["Institute Linter Rule Naming"]),
                .executable(name: "Institute Architecture CLI", targets: ["Institute Architecture CLI"]),
              ],
              targets: [
                .target(name: "Institute Linter Rule Naming"),
                .testTarget(
                  name: "Institute Linter Rule Naming Tests",
                  path: "Tests/Institute Linter Rule Naming Tests"
                ),
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `single word lowercase executable name is permitted`() {
        // The issue's named negative control: the executable `institute`.
        let source = """
            let package = Package(
              name: "institute",
              targets: [
                .executableTarget(name: "institute")
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`manifest naming grammar Tests`.`Edge Case` {
    @Test
    func `third party dependency names are not policed`() {
        // `.product(name:package:)` and `.package(url:)` name what the
        // upstream owner declared; the rule must stay silent on them.
        let source = """
            let package = Package(
              name: "swift-example",
              dependencies: [
                .package(url: "https://github.com/apple/swift-collections.git", branch: "main")
              ],
              targets: [
                .target(
                  name: "Example",
                  dependencies: [
                    .product(name: "OrderedCollections", package: "swift-collections")
                  ]
                )
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `substantive path difference is silent residue`() {
        // The settled `Tests/Support` convention: the segment differs from
        // the target name in substance, not spacing — out of the
        // correspondence predicate's reach, deliberately silent.
        let source = """
            let package = Package(
              name: "swift-memory",
              targets: [
                .target(name: "Memory Test Support", path: "Tests/Support")
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `brand token words are exempt`() {
        let source = """
            let package = Package(
              name: "swift-github-standard",
              targets: [
                .target(name: "GitHub Standard")
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested test manifest package name testing is permitted`() {
        let source = """
            let package = Package(name: "testing")
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non manifest file is out of surface`() {
        let source = """
            let package = Package(name: "NotAManifest", targets: [.target(name: "FooBar")])
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(
            in: source,
            file: "Sources/App/Builder.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `versioned manifest variant is in surface`() {
        let source = """
            let package = Package(name: "Bad_Name")
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(
            in: source,
            file: "Package@swift-6.2.swift"
        )
        #expect(findings.count == 1)
    }

    // Near-miss — spaced overall, one word still concatenated.
    @Test
    func `spaced name with one concatenated word still fires`() {
        let source = """
            let package = Package(
              name: "institute-application",
              targets: [
                .target(name: "Institute ArchitectureCLI")
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("'ArchitectureCLI'") == true)
    }

    @Test
    func `matching path segment is permitted`() {
        let source = """
            let package = Package(
              name: "institute-application",
              targets: [
                .target(name: "Institute Application", path: "Sources/Institute Application")
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // ── .systemLibrary factory (C-shim naming ruling, #65 principal
    //    ruling 2026-08-10: system-library targets take the same spaced
    //    grammar as every other target). ──

    // Positive control for the amended factory set: a concatenated
    // compound systemLibrary name fires exactly like a .target name.
    @Test
    func `concatenated system library name is flagged`() {
        let source = """
            let package = Package(
              name: "swift-image-magick",
              targets: [
                .systemLibrary(name: "CImageMagickShim", pkgConfig: "MagickWand-7.Q16HDRI")
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("CImageMagickShim") == true)
    }

    // The ruled shape is silent.
    @Test
    func `spaced system library name is permitted`() {
        let source = """
            let package = Package(
              name: "swift-image-magick",
              targets: [
                .systemLibrary(name: "Image Magick Shims", pkgConfig: "MagickWand-7.Q16HDRI")
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Near-miss, recorded owner boundary: a single lowercase word
    // (`imagemagick`, the live fleet instance) is silent HERE by the
    // grammar's own single-word rule (the `institute` executable
    // precedent); the `* Shims` shape half of the ruling is the
    // validator family's predicate (R2a), not this rule's.
    @Test
    func `single lowercase system library name is silent residue owned by the validator`() {
        let source = """
            let package = Package(
              name: "swift-image-magick",
              targets: [
                .systemLibrary(name: "imagemagick", pkgConfig: "MagickWand-7.Q16HDRI")
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // The path-correspondence predicate covers .systemLibrary too (it
    // carries `path:` like any target factory).
    @Test
    func `concatenated path segment under a spaced system library is flagged`() {
        let source = """
            let package = Package(
              name: "swift-image-magick",
              targets: [
                .systemLibrary(name: "Image Magick Shims", path: "Sources/ImageMagickShims")
              ]
            )
            """
        let findings = Lint.Rule.`manifest naming grammar Tests`.findings(in: source)
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("ImageMagickShims") == true)
    }
}
