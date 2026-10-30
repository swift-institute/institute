import Lint
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Primitives_Linter_Rule_Tower

extension Lint.Rule {
    @Suite
    struct `clone-less box Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct Negative {}
    }
}

extension Lint.Rule.`clone-less box Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`clone-less box`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`clone-less box Tests`.Unit {
    @Test
    func `suppressed-only box replacement without a twin is flagged`() {
        let findings = Lint.Rule.`clone-less box Tests`.findings(
            in: """
                extension Dictionary where S: ~Copyable {
                    public mutating func removeAll<K: Swift.Hashable & ~Copyable, V: ~Copyable>()
                    where S == Shared<Hash.Entry<K, V>, Engine<K, V>> {
                        self.store = Shared(Engine<K, V>())
                    }
                }
                """
        )
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "clone-less box")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `suppressed initializer constructing the box without a twin is flagged`() {
        let findings = Lint.Rule.`clone-less box Tests`.findings(
            in: """
                extension Stack {
                    public init<Element: ~Copyable>(building: Element) {
                        self.store = Shared(Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>>.Linear())
                    }
                }
                """
        )
        #expect(findings.count == 1)
    }

    @Test
    func `where-clause suppression on an own parameter counts`() {
        let findings = Lint.Rule.`clone-less box Tests`.findings(
            in: """
                extension Queue {
                    public mutating func reset<E>() where E: ~Copyable, S == Shared<E, Ring<E>> {
                        self.store = Shared(Ring<E>())
                    }
                }
                """
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`clone-less box Tests`.`Edge Case` {
    @Test
    func `extension-level column suppression alone does not count`() {
        let findings = Lint.Rule.`clone-less box Tests`.findings(
            in: """
                extension Deque where S: ~Copyable {
                    public mutating func reset() {
                        self.store = Shared(Ring())
                    }
                }
                """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `suppressed overload without a box assignment is silent`() {
        let findings = Lint.Rule.`clone-less box Tests`.findings(
            in: """
                extension Dictionary {
                    public mutating func removeAll<K: ~Copyable, V: ~Copyable>() {
                        store.removeAll()
                    }
                }
                """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `local Shared construction without self assignment is silent`() {
        let findings = Lint.Rule.`clone-less box Tests`.findings(
            in: """
                extension SlotMap {
                    public func snapshot<E: ~Copyable>() -> Shared<E, Slots<E>> {
                        let fresh = Shared(Slots<E>())
                        return fresh
                    }
                }
                """
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`clone-less box Tests`.Negative {
    @Test
    func `the pinned pair is lawful — suppressed overload with an implicitly-Copyable twin`() {
        let findings = Lint.Rule.`clone-less box Tests`.findings(
            in: """
                extension Dictionary where S: ~Copyable {
                    public mutating func removeAll<K: Swift.Hashable, V>()
                    where S == Shared<Hash.Entry<K, V>, Engine<K, V>> {
                        self.store = Shared(Engine<K, V>())
                    }

                    public mutating func removeAll<K: Swift.Hashable & ~Copyable, V: ~Copyable>()
                    where S == Shared<Hash.Entry<K, V>, Engine<K, V>> {
                        self.store = Shared(Engine<K, V>())
                    }
                }
                """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `suppression-free box replacement is lawful alone`() {
        let findings = Lint.Rule.`clone-less box Tests`.findings(
            in: """
                extension Array {
                    public mutating func reset<E>() where S == Shared<E, Linear<E>> {
                        self.store = Shared(Linear<E>())
                    }
                }
                """
        )
        #expect(findings.isEmpty)
    }
}
