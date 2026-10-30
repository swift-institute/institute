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
    struct `phantom suppression Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`phantom suppression Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`phantom suppression`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`phantom suppression Tests`.Unit {
    @Test
    func `extension Tagged where Tag is ~Copyable-only is flagged`() {
        let source = """
            extension Tagged where Underlying == Ordinal, Tag: ~Copyable {
                public var probe: Int { 0 }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "phantom suppression")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `init generic Tag used as Tagged discriminator is flagged`() {
        let source = """
            extension Int {
                public init<Tag: ~Copyable>(_ x: Tagged<Tag, Ordinal>) { self = 0 }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `typealias Index phantom Element is flagged`() {
        let source = "public typealias Index<Element: ~Copyable> = Tagged<Element, Ordinal>"
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension Property where Tag is ~Copyable-only is flagged`() {
        let source = """
            extension Property where Tag: ~Copyable {
                public var probe: Int { 0 }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `function generic Tag used as Tagged discriminator is flagged`() {
        let source = """
            extension Int {
                public func make<Tag: ~Copyable>(_ x: Tagged<Tag, Ordinal>) -> Int { 0 }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `subscript generic Tag used as Tagged discriminator is flagged`() {
        let source = """
            extension Int {
                public subscript<Tag: ~Copyable>(x: Tagged<Tag, Ordinal>) -> Int { 0 }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `doc comment prose does not silence a genuine finding`() {
        // `usedAsStoredValue` matches `"[Tag]"`, `"-> Tag"`, `": Tag "` as text
        // heuristics; a `///` doc comment mentioning `[Tag]` must not read as
        // code and suppress the real finding below.
        let source = """
            /// See [Tag] for background.
            extension Tagged where Underlying == Ordinal, Tag: ~Copyable {
                public var probe: Int { 0 }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `doc comment prose does not manufacture a false positive`() {
        // A doc comment showing `Tagged<Tag, Underlying>` must not turn a
        // non-phantom parameter into a flagged one.
        let source = """
            extension Sequence {
                /// Works like `Tagged<Tag, Underlying>` conceptually.
                public func collect<Tag: ~Copyable>(_ x: [Tag]) {}
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`phantom suppression Tests`.`Edge Case` {
    @Test
    func `already-maximal ~Copyable and ~Escapable is NOT flagged`() {
        let source = """
            extension Tagged where Underlying == Ordinal, Tag: ~Copyable & ~Escapable {
                public var probe: Int { 0 }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stored Element parameter is NOT flagged`() {
        // Element is the stored payload (Array element), not a phantom discriminator.
        let source = """
            extension Sequence {
                public func collect<Element: ~Copyable>(_ x: [Element]) {}
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `param both phantom and stored is conservatively NOT flagged`() {
        // Tag is used as a Tagged discriminator AND as a by-value parameter — the
        // rule never warns when the param appears in any stored position.
        let source = """
            extension Int {
                public init<Tag: ~Copyable>(_ x: Tagged<Tag, Ordinal>, raw: Tag) { self = 0 }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension of a non-wrapper type is NOT flagged`() {
        let source = """
            extension MyContainer where Element: ~Copyable {
                public var probe: Int { 0 }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stored Underlying requirement in Tagged extension is NOT flagged`() {
        // Underlying is Tagged's STORED value parameter, not the phantom —
        // `~Copyable`-only is the correct bound there. FP class surfaced on
        // swift-tagged' own surface (Tagged.swift map/retag
        // extensions, 2026-07-07).
        let source = """
            extension Tagged where Tag: ~Copyable & ~Escapable, Underlying: ~Copyable {
                public var probe: Int { 0 }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `positive Escapable composition on stored Underlying is NOT flagged`() {
        // `Underlying: Escapable & ~Copyable` — the conditional-conformance
        // companion shape (Tagged.swift:116). Stored param, out of scope.
        let source = """
            extension Tagged: Escapable where Tag: ~Copyable & ~Escapable, Underlying: Escapable & ~Copyable {}
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Index extension with copyable-only Element phantom IS flagged`() {
        // Index's phantom parameter is `Element` (Index<Element> =
        // Tagged<Element, Ordinal>) — copyable-only on the phantom fires.
        let source = """
            extension Index where Element: ~Copyable {
                public var probe: Int { 0 }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `same-signature where-clause container binding is NOT flagged`() {
        // #33 regression fixture — the swift-array#9 shape
        // (adjudication comment 5134794606, 2026-07-30): `E` looks like an
        // `Index<E>` phantom discriminator by the text heuristic, but the
        // init's own `where` clause binds the ENCLOSING type's `S` parameter
        // to a concrete storage type that nests `E` as `Contiguous<E>`'s
        // generic argument — `E` is the stored element type, not a phantom.
        // Negative control for `usedAsWhereClauseContainerBinding`.
        let source = """
            struct Container<S: ~Copyable> {
                init<E: ~Copyable, Resource: ~Copyable>(initialCapacity: Index<E>.Count)
                where S == Buffer<Storage::Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Linear {
                    fatalError()
                }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `where-clause binding on an unrelated parameter still flags the true phantom`() {
        // The container-binding exemption is scoped to the SPECIFIC parameter
        // reached by the where-clause nesting — a sibling phantom parameter
        // with no such binding must still fire.
        let source = """
            struct Container<S: ~Copyable> {
                init<E: ~Copyable, Tag: ~Copyable, Resource: ~Copyable>(
                    initialCapacity: Index<E>.Count, x: Tagged<Tag, Ordinal>
                )
                where S == Buffer<Storage::Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Linear {
                    fatalError()
                }
            }
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        // Exactly one finding: `Tag` (no container binding fires); `E` (which
        // has one) stays exempt.
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "phantom suppression")
        }
    }
}

// Prescribed-fix-does-not-compile defect — ruled
// swift-institute/.github#90 comment 5150641576 item 1 (batch-1 backlog,
// comment 5150595934: "ordinal: phantom-suppression prescribed
// fix doesn't compile (UnsafeMutablePointer Pointee structurally
// Escapable)"). `UnsafeMutablePointer.Pointee` has no `~Escapable`
// suppression, so `<P: ~Copyable & ~Escapable>` is rejected by the
// compiler; such a parameter is not a pure phantom.
extension Lint.Rule.`phantom suppression Tests`.`Edge Case` {
    @Test
    func `parameter used as UnsafeMutablePointer Pointee is NOT flagged`() {
        let source = """
            func store<E: ~Copyable>(
                _ pointer: UnsafeMutablePointer<E>,
                at index: Index<E>
            ) {}
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `parameter used as UnsafePointer Pointee is NOT flagged`() {
        let source = """
            func load<E: ~Copyable>(
                _ pointer: UnsafePointer<E>,
                at index: Index<E>
            ) {}
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `parameter used as UnsafeBufferPointer Element is NOT flagged`() {
        let source = """
            func scan<E: ~Copyable>(
                _ buffer: UnsafeBufferPointer<E>,
                from index: Index<E>
            ) {}
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Near-miss / positive control: the same declaration WITHOUT the pointer
    // position is a pure phantom and still fires.
    @Test
    func `phantom discriminator without a pointer position is still flagged`() {
        let source = """
            func advance<E: ~Copyable>(_ index: Index<E>, by step: Int) {}
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Near-miss: a similarly-named but distinct type does not carry the
    // stdlib Escapable constraint, so the exemption must not apply.
    @Test
    func `a non-stdlib pointer-like generic does NOT exempt the phantom`() {
        let source = """
            func advance<E: ~Copyable>(_ handle: MyPointer<E>, at index: Index<E>) {}
            """
        let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`phantom suppression Tests`.`Edge Case` {
    @Test
    func `module-qualified ~Swift.Escapable counts as maximal`() {
        let findings = Lint.Rule.`phantom suppression Tests`.findings(
            in: "extension Tagged: Swift.Escapable where Tag: ~Copyable & ~Swift.Escapable, Underlying: Swift.Escapable & ~Copyable {}"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `module-qualified ~Swift.Copyable alone is still flagged`() {
        let findings = Lint.Rule.`phantom suppression Tests`.findings(
            in: "extension Tagged where Underlying == Ordinal, Tag: ~Swift.Copyable { public var probe: Int { 0 } }"
        )
        #expect(findings.count == 1)
    }
}
