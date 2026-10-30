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
    struct `canimport conditional Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`canimport conditional Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`canimport conditional`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`canimport conditional Tests`.Unit {
    @Test
    func `canImport Darwin Kernel Standard is flagged`() {
        let source = """
            #if canImport(Darwin_Kernel_Standard)
            import Darwin_Kernel_Standard
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "canimport conditional")
            #expect(findings[0].severity == .warning)
        }
    }

    // #16 Option C ledger, Entry II.2 (DECISION 2026-07-23): bare
    // C-library modules are module availability, not platform identity —
    // the libc trellis cannot be expressed with `os()` (`os(Linux)` cannot
    // distinguish Glibc from Musl).
    @Test
    func `canImport bare Darwin is NOT flagged - C-library module availability`() {
        let source = """
            #if canImport(Darwin)
            import Darwin
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `libc trellis is NOT flagged - Darwin Glibc Musl disjunction`() {
        let source = """
            #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
            import CInterop
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `canImport bare Linux is flagged - not an importable module`() {
        // `Linux` is not a real module; `canImport(Linux)` is an always-false
        // platform-identity confusion and remains flagged.
        let source = """
            #if canImport(Linux)
            import Glibc
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `canImport Linux underscored is flagged`() {
        let source = """
            #if canImport(Linux_Kernel)
            import Linux_Kernel
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `canImport Glibc is NOT flagged - C-library module availability`() {
        let source = """
            #if canImport(Glibc)
            import Glibc
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `canImport Glibc-prefixed institute module is flagged`() {
        let source = """
            #if canImport(Glibc_Kernel_Standard)
            import Glibc_Kernel_Standard
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `canImport Android-prefixed institute module is flagged`() {
        // Regression guard: bare `Android` was already remembered in the
        // C-library-module exemption set but forgotten in the detection
        // set, so a platform-prefixed module built on it went undetected.
        let source = """
            #if canImport(Android_Kernel_Standard)
            import Android_Kernel_Standard
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `canImport bare Android is NOT flagged - C-library module availability`() {
        let source = """
            #if canImport(Android)
            import Android
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `canImport WASI-prefixed institute module is flagged`() {
        let source = """
            #if canImport(WASI_System)
            import WASI_System
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `canImport FreeBSD-prefixed institute module is flagged`() {
        let source = """
            #if canImport(FreeBSD_Kernel)
            import FreeBSD_Kernel
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `canImport Windows in elseif is flagged`() {
        let source = """
            #if os(macOS)
            import Foundation
            #elseif canImport(Windows_Kernel)
            import Windows_Kernel
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #21 defect 13: previously-untested reachable branches.

    @Test
    func `negated canImport Darwin Kernel is flagged`() {
        let source = """
            #if !canImport(Darwin_Kernel)
            import Fallback
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `os check conjoined with canImport Linux Kernel is flagged`() {
        let source = """
            #if os(Linux) && canImport(Linux_Kernel)
            import Linux_Kernel
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `qualified canImport Darwin dot POSIX resolves to the exempt root`() {
        // Darwin is an exempt C-library module; this checks the exemption
        // is applied to the resolved root (`Darwin`), not the member-access
        // leaf (`POSIX`).
        let source = """
            #if canImport(Darwin.POSIX)
            import Darwin.POSIX
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`canimport conditional Tests`.`Edge Case` {
    @Test
    func `if os macOS is NOT flagged`() {
        let source = """
            #if os(macOS)
            let x = 1
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `canImport SwiftUI is NOT flagged`() {
        let source = """
            #if canImport(SwiftUI)
            import SwiftUI
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `canImport Combine is NOT flagged`() {
        let source = """
            #if canImport(Combine)
            import Combine
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `os check with multiple platforms is NOT flagged`() {
        let source = """
            #if os(macOS) || os(iOS) || os(tvOS)
            import Darwin_Kernel_Standard
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-canImport function call is NOT flagged`() {
        // Plain `#if` with arbitrary expression — not relevant to rule.
        let source = """
            #if DEBUG
            let x = 1
            #endif
            """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
