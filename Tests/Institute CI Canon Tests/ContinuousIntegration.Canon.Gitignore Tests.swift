import Institute_CI_Model
import Testing

@testable import Institute_CI_Canon

@Suite
struct CICanonGitignoreTests {
    static let terminator = ContinuousIntegration.Canon.Gitignore.terminator
    static let canon =
        "# CANONICAL\n/*\n!/Sources/\n"
        + ContinuousIntegration.Canon.Gitignore.Capability.block
        + "\(terminator)\n"

    @Suite
    struct Unit {
        @Test func `the generated marker is recognized`() {
            let file = ContinuousIntegration.Canon.Gitignore(CICanonGitignoreTests.canon)
            #expect(file.isGenerated)
            #expect(file.generatedPrefix == CICanonGitignoreTests.canon)
        }

        @Test func `a pre canonical file has no generated marker`() {
            // Absence is a [GH-IGNORE-001] finding to the validator and
            // replacement input to the complete-policy renderer.
            let file = ContinuousIntegration.Canon.Gitignore(".build/\n")
            #expect(!file.isGenerated)
            #expect(file.generatedPrefix == nil)
        }

        @Test func `rendering over a canonical file replaces the complete policy`() throws {
            let existing = ContinuousIntegration.Canon.Gitignore(
                "# OLD\n\(ContinuousIntegration.Canon.Gitignore.terminator)\nown/\n"
            )
            let rendered = try ContinuousIntegration.Canon.Gitignore.Render(
                canon: .init(CICanonGitignoreTests.canon)
            )(over: existing)
            #expect(rendered == CICanonGitignoreTests.canon)
        }

        @Test func `rendering over no file emits canon whole`() throws {
            let canon = CICanonGitignoreTests.canon
            let rendered = try ContinuousIntegration.Canon.Gitignore.Render(
                canon: .init(canon)
            )(over: nil)
            #expect(rendered == canon)
        }

        @Test func `rendering is idempotent`() throws {
            // The caller byte-compares before committing, so a second
            // render of a conformant file must produce no change.
            let render = try ContinuousIntegration.Canon.Gitignore.Render(
                canon: .init(CICanonGitignoreTests.canon)
            )
            let once = render(over: nil)
            let twice = render(over: .init(once))
            #expect(once == twice)
        }

        @Test func `a Windows text checkout retains its closed admissions`() throws {
            var canon = ""
            for character in CICanonGitignoreTests.canon {
                if character == "\n" { canon.append("\r") }
                canon.append(character)
            }
            let rendered = try ContinuousIntegration.Canon.Gitignore.Render(
                canon: .init(canon)
            )(over: nil)
            #expect(rendered == canon)
        }
    }

    @Suite
    struct Class {
        typealias Class = ContinuousIntegration.Canon.Gitignore.Class

        @Test func `every class names its own canon document`() {
            #expect(Class.package.canonPath == "canon/gitignore-package.txt")
            for `class` in Class.allCases {
                #expect(`class`.canonPath == "canon/gitignore-\(`class`.rawValue).txt")
            }
        }

        @Test func `classification authority order is assignment, org, manifest`() {
            // Assignments are empty today; the derivations carry the
            // fleet. The control-plane org outranks manifest facts, and
            // the manifest's generator fact outranks the package default.
            #expect(Class.of(repository: "swift-institute/Research", manifest: nil) == .institute)
            #expect(
                Class.of(
                    repository: "swift-institute/institute-continuous-integration",
                    manifest: "// swift-tools-version: 6.3"
                ) == .institute
            )
            #expect(Class.of(repository: "swift-primitives/x", manifest: "…") == .package)
            #expect(Class.of(repository: "swift-primitives/x", manifest: nil) == .scaffold)
            #expect(
                Class.of(
                    repository: "swift-standards/x",
                    manifest: #".executableTarget(name: "SVG Generator")"#
                ) == .generator
            )
        }

        @Test func `no repository is assigned before the convergence ruling`() {
            // The typed exception list is admitted by ruling, not by
            // drift; an entry appearing here must arrive with the ruling
            // that admits it.
            #expect(Class.assignments.isEmpty)
        }
    }

    @Suite
    struct `Edge Case` {
        @Test func `a pre canonical file is replaced rather than preserved as a tail`() throws {
            let rendered = try ContinuousIntegration.Canon.Gitignore.Render(
                canon: .init(CICanonGitignoreTests.canon)
            )(over: .init("\n\nlegacy/\n"))
            #expect(rendered == CICanonGitignoreTests.canon)
        }

        @Test func `a file ending at the terminator is generated`() {
            let file = ContinuousIntegration.Canon.Gitignore(
                "/*\n\(ContinuousIntegration.Canon.Gitignore.terminator)"
            )
            #expect(file.isGenerated)
            #expect(file.generatedPrefix?.hasSuffix("\n") == true)
        }

        @Test func `canon without a terminator is refused, not reported`() {
            // An unusable control-plane document is not a verdict about
            // any package.
            #expect(
                throws: ContinuousIntegration.Canon.Gitignore.Render.Error
                    .terminatorAbsent
            ) {
                try ContinuousIntegration.Canon.Gitignore.Render(canon: .init("/*\n"))
            }
        }
    }

    @Test func `the policy vocabulary is closed at six capabilities`() {
        typealias Capability = ContinuousIntegration.Canon.Gitignore.Capability
        #expect(
            Capability.allCases.map(\.rawValue) == [
                "benchmark baseline", "snapshot baseline", "environment example",
                "repository policy corpus", "fixture provenance manifest", "editor configuration",
            ]
        )
        #expect(
            Capability.allCases.map(\.admission) == [
                "!**/.benchmarks/", "!**/.snapshots/", "!/.env.example", "!/canon/",
                "!**/Fixtures/MANIFEST.md", "!/.editorconfig",
            ]
        )
    }

    @Test func `nested package policy is exact`() {
        #expect(
            ContinuousIntegration.Canon.Gitignore.Nested.roots == ["Tests", "Benchmarks"]
        )
        #expect(
            ContinuousIntegration.Canon.Gitignore.Nested.text
                == ".build/\n.swiftpm/\n.benchmarks/\n"
        )
        #expect(
            ContinuousIntegration.Canon.Gitignore.Nested.policies(
                declarations: ["Tests/Package.swift"]
            ) == ["Tests/.gitignore": ".build/\n.swiftpm/\n.benchmarks/\n"]
        )
    }
}
