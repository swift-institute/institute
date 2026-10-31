import Lint
import Linter_Rules_Test_Support
import Testing

@testable import App_Linter_Rule_Framework

@Suite
struct `framework import Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `framework import Tests` {
    static func findings(_ source: Swift::String, file: Swift::String) -> [Diagnostic.Record] {
        Lint.Rule.`framework import`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
    }
}

extension `framework import Tests`.Unit {
    @Test(arguments: [
        "import PDFKit",
        "public import Vision",
        "@_exported public import FoundationModels",
        "import struct PDFKit.PDFDocument",
        "@preconcurrency import CryptoKit",
        "import UniformTypeIdentifiers",
        "import OSLog",
        "import CloudKit",
    ])
    func `an Apple framework in a core target fires`(source: Swift::String) {
        #expect(`framework import Tests`.findings(source, file: "Sources/Reader/Reader.swift").count == 1, "\(source)")
    }

    @Test(arguments: ["import Foundation", "import Dispatch", "import Observation", "import Synchronization", "import Reader"])
    func `a portable module does not fire`(source: Swift::String) {
        #expect(`framework import Tests`.findings(source, file: "Sources/Reader/Reader.swift").isEmpty, "\(source)")
    }

    @Test(arguments: [
        ("import PDFKit", "Sources/Reader PDFKit/Reader.PDF+PDFKit.swift"),
        ("import Vision", "Sources/Reader Vision/Reader.Recognizer+Vision.swift"),
        ("import FoundationModels", "Sources/Reader FoundationModels/Reader.Model+FoundationModels.swift"),
        ("import WebKit", "Sources/Affairs WebKit/Browser.swift"),
        ("import CloudKit", "Sources/Affairs CloudKit/Sync.swift"),
        ("import CloudKit", "Sources/SQLite CloudKit/SyncEngine.swift"),
        ("import AppKit", "Sources/Kees AppKit/Panel.swift"),
        ("import SwiftUI", "Sources/Kees SwiftUI/Organizer.View.swift"),
    ])
    func `an adapter imports its own framework`(source: Swift::String, file: Swift::String) {
        #expect(`framework import Tests`.findings(source, file: file).isEmpty, "\(file)")
    }

    @Test(arguments: [
        ("import CoreGraphics", "Sources/Reader PDFKit/Reader.PDF+PDFKit.swift"),
        ("import AppKit", "Sources/Reader PDFKit/Reader.PDF+PDFKit.swift"),
        ("import PDFKit", "Sources/Laurie SwiftUI/Retrieval.View.Preview.swift"),
        ("import VisionKit", "Sources/Laurie SwiftUI/Inventory.View.swift"),
        ("import CoreSpotlight", "Sources/Laurie AppIntents/Assistant.swift"),
    ])
    func `an adapter imports a companion of its framework`(source: Swift::String, file: Swift::String) {
        #expect(`framework import Tests`.findings(source, file: file).isEmpty, "\(file)")
    }

    @Test(arguments: [
        ("import PDFKit", "Sources/Affairs PDFKit/Affairs.PDF.swift"),
        ("import FoundationModels", "Sources/Docket FoundationModels/Pointer.swift"),
        ("import WebKit", "Sources/Reader WebKit/Browser.swift"),
    ])
    func `an adapter of another family fires`(source: Swift::String, file: Swift::String) {
        #expect(`framework import Tests`.findings(source, file: file).count == 1, "\(file)")
    }
}

extension `framework import Tests`.`Edge Case` {
    @Test
    func `an import inside a conditional fires`() {
        let source = "#if os(macOS)\nimport PDFKit\n#endif"
        #expect(`framework import Tests`.findings(source, file: "Sources/Reader/Reader.swift").count == 1)
    }

    @Test
    func `an adapter's test target counts as the adapter`() {
        #expect(`framework import Tests`.findings("import PDFKit", file: "Tests/Reader PDFKit Tests/Reader.PDF Tests.swift").isEmpty)
    }

    @Test
    func `a core test target does not count as an adapter`() {
        #expect(`framework import Tests`.findings("import PDFKit", file: "Tests/Reader Tests/Reader Tests.swift").count == 1)
    }

    @Test(arguments: ["Sources/Reader PDFKitty/Reader.swift", "Sources/PDFKit Reader/Reader.swift", "Sources/PDFKit/Reader.swift"])
    func `near miss: a name that is not '<owner> PDFKit' fires`(file: Swift::String) {
        #expect(`framework import Tests`.findings("import PDFKit", file: file).count == 1, "\(file)")
    }

    @Test(arguments: ["main.swift", "Reader.swift", "Package.swift"])
    func `a bare filename fires`(file: Swift::String) {
        #expect(`framework import Tests`.findings("import PDFKit", file: file).count == 1, "\(file)")
    }

    @Test
    func `a host imports presentation frameworks only`() {
        #expect(`framework import Tests`.findings("import SwiftUI\nimport AppKit", file: "Hosts/Kees/Kees/KeesApp.swift").isEmpty)
        #expect(`framework import Tests`.findings("import PDFKit", file: "Hosts/Kees/Kees/KeesApp.swift").count == 1)
    }

    @Test
    func `the message names the owner`() {
        let message = `framework import Tests`.findings("import PDFKit", file: "Sources/Reader/Reader.swift").first?.message ?? ""
        #expect(message.contains("PDFKit") && message.contains("Reader"))
    }
}

extension `framework import Tests`.Integration {
    @Test
    func `controls hold`() {
        let outcomes = Lint.Rule.`framework import`.outcomes()
        #expect(outcomes.contains { $0.expected > 0 })
        #expect(outcomes.contains { $0.expected == 0 })
        for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
    }
}
