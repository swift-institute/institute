import Lint
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_Memory

@Suite
struct `unsafe storage visibility Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `unsafe storage visibility Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Sources/X/Test.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`unsafe storage visibility`.observe(parsed, .warning).findings
    }
}

extension `unsafe storage visibility Tests`.Unit {
    @Test
    func `public unsafe pointer property is flagged`() {
        let source = """
            struct Buffer {
                public let storage: UnsafeMutablePointer<UInt8>
            }
            """
        let findings = `unsafe storage visibility Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `private unsafe pointer property is permitted`() {
        let source = """
            struct Buffer {
                private let storage: UnsafeMutablePointer<UInt8>
            }
            """
        let findings = `unsafe storage visibility Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `internal unsafe pointer property is permitted`() {
        let source = """
            struct Buffer {
                let storage: UnsafeMutablePointer<UInt8>
            }
            """
        let findings = `unsafe storage visibility Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public unsafe pointer with unsafe attr is permitted`() {
        let source = """
            struct Buffer {
                @unsafe public let storage: UnsafeMutablePointer<UInt8>
            }
            """
        let findings = `unsafe storage visibility Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public non-pointer property is not flagged`() {
        let source = """
            struct Foo {
                public let count: Int
            }
            """
        let findings = `unsafe storage visibility Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `optional unsafe pointer property still flagged`() {
        let source = """
            struct Buffer {
                public let storage: UnsafeMutablePointer<UInt8>?
            }
            """
        let findings = `unsafe storage visibility Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple unsafe pointer types in allowlist`() {
        let source = """
            struct Buffer {
                public let raw: UnsafeRawPointer
                public let mutableRaw: UnsafeMutableRawPointer
                public let buf: UnsafeBufferPointer<UInt8>
            }
            """
        let findings = `unsafe storage visibility Tests`.findings(in: source)
        #expect(findings.count == 3)
    }
}
