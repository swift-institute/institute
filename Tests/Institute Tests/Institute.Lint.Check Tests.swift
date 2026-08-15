import File_System
import Foundation
import SPM_Standard
import Testing

@testable import Institute_Lint
@testable import Institute_Model

extension Institute.Lint.Check {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Lint.Check.Test.Unit {
    @Test
    func `clean, violations, and failed verdicts report the expected text and failure`() {
        #expect(Institute.Lint.Check.Verdict.clean.text == "clean")
        #expect(!Institute.Lint.Check.Verdict.clean.fails)

        let advisory = Institute.Lint.Check.Verdict.violations(count: 3, failing: false)
        #expect(advisory.text == "3 violations (advisory)")
        #expect(!advisory.fails)

        let failing = Institute.Lint.Check.Verdict.violations(count: 1, failing: true)
        #expect(failing.text == "1 violation (error severity)")
        #expect(failing.fails)

        let failed = Institute.Lint.Check.Verdict.failed(exitCode: 2)
        #expect(failed.text == "failed (exit 2)")
        #expect(failed.fails)

        let unmeasured = Institute.Lint.Check.Verdict.unmeasured(reason: "no binary")
        #expect(unmeasured.text == "UNMEASURED — no binary")
        #expect(unmeasured.fails)
        #expect(unmeasured.isUnmeasured)
    }

    @Test
    func `a report fails when any step fails, and passes only when every step is clean`() {
        let passing = Institute.Lint.Check.Report(steps: [
            .init(name: "swift-format", verdict: .clean),
            .init(name: "build", verdict: .clean),
        ])
        #expect(!passing.fails)

        let failing = Institute.Lint.Check.Report(steps: [
            .init(name: "swift-format", verdict: .clean),
            .init(name: "swiftlint", verdict: .unmeasured(reason: "swiftlint is not on PATH")),
            .init(name: "build", verdict: .clean),
        ])
        #expect(failing.fails)
    }

    @Test
    func `the report renders every step on its own line, in order`() {
        let report = Institute.Lint.Check.Report(steps: [
            .init(name: "swift-format", verdict: .clean),
            .init(name: "swiftlint", verdict: .violations(count: 2, failing: true)),
        ])
        #expect(
            report.description
                == "swift-format: clean\nswiftlint: 2 violations (error severity)"
        )
    }
}

extension Institute.Lint.Check.Test.Unit {
    @Test
    func `the file list matches Sources and Tests swift files only`() throws {
        let path = try Institute.Lint.Check.Test.temporaryPackage()
        let root = try File.Directory(validating: path)
        defer { try? root.delete.recursive() }

        try Institute.Lint.Check.Test.write("", at: path, "Sources/Widget/Widget.swift")
        try Institute.Lint.Check.Test.write("", at: path, "Sources/Widget/Notes.txt")
        try Institute.Lint.Check.Test.write("", at: path, "Tests/Widget Tests/WidgetTests.swift")

        let files = try Institute.Lint.Check.files(under: root)
        let names = Set(files.map(\.description))

        #expect(names.contains("\(path)/Sources/Widget/Widget.swift"))
        #expect(names.contains("\(path)/Tests/Widget Tests/WidgetTests.swift"))
        #expect(!names.contains("\(path)/Sources/Widget/Notes.txt"))
    }
}

extension Institute.Lint.Check.Test.`Edge Case` {
    @Test
    func `docc Resources, top-level Tests-Support, and top-level Tests-Tutorial are excluded`()
        throws
    {
        let path = try Institute.Lint.Check.Test.temporaryPackage()
        let root = try File.Directory(validating: path)
        defer { try? root.delete.recursive() }

        try Institute.Lint.Check.Test.write(
            "",
            at: path,
            "Sources/Widget/Widget.docc/Resources/Sample.swift"
        )
        try Institute.Lint.Check.Test.write("", at: path, "Tests/Support/Fixture.swift")
        try Institute.Lint.Check.Test.write("", at: path, "Tests/Tutorial/Tutorial.swift")
        try Institute.Lint.Check.Test.write("", at: path, "Tests/Widget Tests/Kept.swift")

        let files = try Institute.Lint.Check.files(under: root)
        let names = Set(files.map(\.description))

        #expect(!names.contains("\(path)/Sources/Widget/Widget.docc/Resources/Sample.swift"))
        #expect(!names.contains("\(path)/Tests/Support/Fixture.swift"))
        #expect(!names.contains("\(path)/Tests/Tutorial/Tutorial.swift"))
        #expect(names.contains("\(path)/Tests/Widget Tests/Kept.swift"))
    }

    @Test
    func `a nested Tests-Support directory is not excluded, matching CI's rootless pattern`()
        throws
    {
        // `swift-ci.yml`'s exclusion is `Tests/Support/*`, anchored at the
        // repository root — a `Support` directory nested deeper is real test
        // code and stays in scope.
        let path = try Institute.Lint.Check.Test.temporaryPackage()
        let root = try File.Directory(validating: path)
        defer { try? root.delete.recursive() }

        try Institute.Lint.Check.Test.write(
            "",
            at: path,
            "Tests/Widget Tests/Support/Nested.swift"
        )

        let files = try Institute.Lint.Check.files(under: root)
        let names = Set(files.map(\.description))

        #expect(names.contains("\(path)/Tests/Widget Tests/Support/Nested.swift"))
    }

    @Test
    func `render writes both configs into .build-institute-check, byte for byte`() throws {
        let path = try Institute.Lint.Check.Test.temporaryPackage()
        let root = try File.Directory(validating: path)
        defer { try? root.delete.recursive() }

        let lint = Institute.Lint(hierarchy: root)
        let check = Institute.Lint.Check(lint)
        let rendered = try check.render(into: root)

        let swiftLintContents = try Institute.Lint.read(rendered.swiftLint)
        let swiftFormatContents = try Institute.Lint.read(rendered.swiftFormat)

        #expect(swiftLintContents == Institute.Lint.Profile.swiftLint)
        #expect(swiftFormatContents == Institute.Lint.Profile.swiftFormat)
    }
}

extension Institute.Lint.Check.Test {
    static func temporaryPackage() throws -> Swift.String {
        let base = FileManager.default.temporaryDirectory.appending(
            path: "institute-check-tests-\(UUID().uuidString)"
        )
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.path
    }

    static func write(
        _ contents: Swift.String,
        at root: Swift.String,
        _ relative: Swift.String
    )
        throws
    {
        let url = URL(fileURLWithPath: root).appending(path: relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try File(File.Path(url.path)).write.atomic(contents)
    }
}
