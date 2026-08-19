import JSON
import Testing

@testable import Institute_Instruments
@testable import Institute_Model

extension Institute.Certification.Materialization {
    @Suite
    struct Test {
        static func revision(
            _ digit: Swift.String
        ) throws(Institute.Error)
            -> Institute.Certification.Revision
        {
            try .init(Swift.String(repeating: digit, count: 40))
        }

        static func key() -> Institute.Repository.Key {
            guard
                let key = Institute.Repository.Key(
                    identity: "swift-foundations/swift-example"
                )
            else {
                fatalError("test fixture identity must be valid")
            }
            return key
        }

        static func receipt(
            transformations: [Institute.Certification.Materialization.Transformation] = []
        ) throws(Institute.Error) -> Institute.Certification.Materialization {
            try .init(
                key: key(),
                revision: revision("1"),
                tree: Swift.String(repeating: "2", count: 40),
                transformations: transformations
            )
        }

        @Test
        func `identity is source identity, never location`() throws {
            // The receipt carries no destination, host, or path field at
            // all: equal source facts are equal receipts, wherever and
            // however many times they were materialized.
            let one = try Self.receipt()
            let two = try Self.receipt()
            #expect(one == two)
            #expect(one.digest == two.digest)
        }

        @Test
        func `changing a transformation changes the digest`() throws {
            let none = try Self.receipt()
            let redirected = try Self.receipt(
                transformations: [
                    .init(
                        file: "Package.swift",
                        dependency: "swift-foundations/swift-dependency",
                        target: Self.revision("3")
                    )
                ]
            )
            let retargeted = try Self.receipt(
                transformations: [
                    .init(
                        file: "Package.swift",
                        dependency: "swift-foundations/swift-dependency",
                        target: Self.revision("4")
                    )
                ]
            )
            #expect(none.digest != redirected.digest)
            #expect(redirected.digest != retargeted.digest)
        }

        @Test
        func `transformation order cannot change identity`() throws {
            let a = try Institute.Certification.Materialization.Transformation(
                file: "A/Package.swift",
                dependency: "swift-foundations/swift-a",
                target: Self.revision("3")
            )
            let b = try Institute.Certification.Materialization.Transformation(
                file: "B/Package.swift",
                dependency: "swift-foundations/swift-b",
                target: Self.revision("4")
            )
            let forward = try Self.receipt(transformations: [a, b])
            let backward = try Self.receipt(transformations: [b, a])
            #expect(forward.digest == backward.digest)
        }

        @Test
        func `duplicate transformations for one file are refused`() throws {
            let first = try Institute.Certification.Materialization.Transformation(
                file: "Package.swift",
                dependency: "swift-foundations/swift-a",
                target: Self.revision("3")
            )
            let second = try Institute.Certification.Materialization.Transformation(
                file: "Package.swift",
                dependency: "swift-foundations/swift-b",
                target: Self.revision("4")
            )
            #expect(throws: Institute.Error.self) {
                try Self.receipt(transformations: [first, second])
            }
        }

        @Test
        func `a malformed tree identity is refused`() throws {
            #expect(throws: Institute.Error.self) {
                try Institute.Certification.Materialization(
                    key: Self.key(),
                    revision: Self.revision("1"),
                    tree: "short",
                    transformations: []
                )
            }
            #expect(throws: Institute.Error.self) {
                try Institute.Certification.Materialization(
                    key: Self.key(),
                    revision: Self.revision("1"),
                    tree: Swift.String(repeating: "A", count: 40),
                    transformations: []
                )
            }
        }

        @Test
        func `serialization round-trips through the sealed canonical form`() throws {
            let receipt = try Self.receipt(
                transformations: [
                    .init(
                        file: "Package.swift",
                        dependency: "swift-foundations/swift-dependency",
                        target: Self.revision("3")
                    )
                ]
            )
            let decoded = try Institute.Certification.Materialization(
                jsonString: receipt.canonical
            )
            #expect(decoded == receipt)
            #expect(decoded.digest == receipt.digest)
        }
    }
}
