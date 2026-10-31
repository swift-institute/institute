import Lint
import Linter_Rules_Test_Support
import Testing

@testable import App_Linter_Rule_Framework

@Suite
struct `owned api Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `owned api Tests` {
    static func findings(_ source: Swift::String, file: Swift::String = "Sources/Affairs SQLite/Originals.swift") -> [Diagnostic.Record] {
        Lint.Rule.`owned api`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
    }
}

extension `owned api Tests`.Unit {
    @Test(arguments: [
        "let files = FileManager.default",
        "try FileManager.default.moveItem(at: a, to: b)",
        "let coordinator = NSFileCoordinator()",
        "let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url)",
        "let query = NSMetadataQuery()",
        "let scoped = url.startAccessingSecurityScopedResource()",
        "url.stopAccessingSecurityScopedResource()",
        "let bookmark = try url.bookmarkData()",
        "let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)",
        "try manager.startDownloadingUbiquitousItem(at: url)",
        "let bytes = try Data(contentsOf: url)",
        "let bytes = try Data.init(contentsOf: url)",
        "let state = ProcessInfo.processInfo.thermalState",
        "let low = ProcessInfo.processInfo.isLowPowerModeEnabled",
        "let activity = ProcessInfo.processInfo.beginActivity(options: [], reason: \"\")",
        "let document = PDFDocument(data: data)",
        "let page = PDFPage(image: image)",
        "let object = try JSONSerialization.jsonObject(with: data)",
    ])
    func `each owned name fires outside its owner`(source: Swift::String) {
        #expect(`owned api Tests`.findings(source).count == 1, "\(source)")
    }

    @Test(arguments: [
        ("let files = FileManager.default", "Sources/File System Foundation Integration/File.Ubiquitous.swift"),
        ("let bytes = try Data(contentsOf: url)", "Sources/Paths Foundation Integration/Path+Foundation.URL.swift"),
        ("let state = ProcessInfo.processInfo.thermalState", "Sources/Reader Darwin/Reader.Queue.Power+Darwin.swift"),
        ("let page = PDFPage(image: image)", "Sources/Reader PDFKit/Reader.PDF+PDFKit.swift"),
    ])
    func `the owner may use it`(source: Swift::String, file: Swift::String) {
        #expect(`owned api Tests`.findings(source, file: file).isEmpty, "\(file)")
    }

    @Test
    func `no target owns JSONSerialization`() {
        #expect(`owned api Tests`.findings("let o = try JSONSerialization.jsonObject(with: d)", file: "Sources/X Foundation Integration/X.swift").count == 1)
    }
}

extension `owned api Tests`.`Edge Case` {
    @Test
    func `a qualified name counts once`() {
        #expect(`owned api Tests`.findings("try Foundation.FileManager.default.removeItem(at: url)").count == 1)
    }

    @Test
    func `a type alias fires at its declaration`() {
        #expect(`owned api Tests`.findings("typealias Files = FileManager").count == 1)
    }

    @Test
    func `comments and strings do not fire`() {
        #expect(`owned api Tests`.findings("// FileManager\nlet name = \"FileManager\"\n/// thermalState").isEmpty)
    }

    @Test(arguments: ["let m = File.Manager()", "let d = Data(count: 4)", "let d = Data(contentsOfFile: path)", "let x = document.contentsOf"])
    func `near misses do not fire`(source: Swift::String) {
        #expect(`owned api Tests`.findings(source).isEmpty, "\(source)")
    }

    @Test(arguments: ["Sources/Kees Foundation Integrationx/X.swift", "Sources/Reader Darwinian/X.swift", "Sources/Foundation Integration/X.swift"])
    func `near miss: an owner suffix that is not a whole word fires`(file: Swift::String) {
        let source = "let files = FileManager.default\nlet state = ProcessInfo.processInfo.thermalState"
        #expect(`owned api Tests`.findings(source, file: file).count == 2, "\(file)")
    }

    @Test
    func `test targets are not checked`() {
        #expect(`owned api Tests`.findings("let files = FileManager.default", file: "Tests/Affairs Tests/Originals Tests.swift").isEmpty)
    }

    @Test(arguments: ["main.swift", "Hosts/Kees/Kees/KeesApp.swift"])
    func `a file outside any target fires`(file: Swift::String) {
        #expect(`owned api Tests`.findings("let files = FileManager.default", file: file).count == 1, "\(file)")
    }
}

extension `owned api Tests`.Integration {
    @Test
    func `controls hold`() {
        let outcomes = Lint.Rule.`owned api`.outcomes()
        #expect(outcomes.contains { $0.expected > 0 })
        #expect(outcomes.contains { $0.expected == 0 })
        for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
    }
}
