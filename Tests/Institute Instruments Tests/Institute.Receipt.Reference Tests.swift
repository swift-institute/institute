import Foundation
import JSON
import Testing

@testable import Institute_Instruments
@testable import Institute_Model

extension Institute.Receipt.Reference {
    @Suite struct Test {}
}

extension Institute.Receipt.Reference.Test {
    private static let digest = Swift.String(repeating: "a", count: 64)

    private static func receipt(
        selection: Swift.String = "policy",
        kind: Swift.String = Institute.Coherence.Receipt.canonicalKind
    ) -> Institute.Coherence.Receipt {
        .init(
            kind: kind,
            instrument: .init(
                workspaceCommit: Swift.String(repeating: "b", count: 40),
                workspaceJsonBlob: Swift.String(repeating: "c", count: 40),
                selection: selection
            ),
            environment: .init(
                platform: "macos",
                swift: "6.4",
                xcode: "26.6",
                runner: "test",
                fresh: true,
                cachesUsed: []
            ),
            population: .init(
                inventoryCount: 1,
                materializedCount: 1,
                builtTargetCount: 1,
                expectedTargetCount: 1
            ),
            heads: [:],
            stages: [],
            verdict: .coherent,
            attribution: nil,
            priorGreenReceipt: nil
        )
    }

    @Test
    func `a reference validates its digest and kind`() throws {
        let reference = try Institute.Receipt.Reference(
            digest: Self.digest,
            kind: "fleet-certificate"
        )
        #expect(reference.digest == Self.digest)

        #expect(throws: Institute.Error.self) {
            _ = try Institute.Receipt.Reference(digest: "short", kind: "x")
        }
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Receipt.Reference(
                digest: Self.digest.uppercased(),
                kind: "x"
            )
        }
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Receipt.Reference(digest: Self.digest, kind: "")
        }
    }

    @Test
    func `a reference round-trips and a corrupt digest is refused`() throws {
        let reference = try Institute.Receipt.Reference(
            digest: Self.digest,
            kind: "fleet-certificate"
        )
        let decoded = try Institute.Receipt.Reference(
            jsonString: reference.json.serialize(sortKeys: true)
        )
        #expect(decoded == reference)

        #expect(throws: JSON.Error.self) {
            _ = try Institute.Receipt.Reference(
                jsonString: "{\"digest\":\"nope\",\"kind\":\"x\"}"
            )
        }
    }

    @Test
    func `a coherence receipt mints a reference addressing its own digest`() throws {
        let receipt = Self.receipt()
        let reference = try receipt.reference()
        #expect(reference.digest == receipt.digest)
        #expect(reference.kind == Institute.Coherence.Receipt.canonicalKind)
    }

    @Test
    func `a non-canonical coherence receipt refuses to be referenced`() {
        let receipt = Self.receipt(selection: "narrowed: swift-color only")
        #expect(throws: Institute.Error.self) {
            _ = try receipt.reference()
        }
    }

    @Test
    func `a coherence receipt of a foreign kind refuses to be referenced`() {
        let receipt = Self.receipt(kind: "something-else")
        #expect(throws: Institute.Error.self) {
            _ = try receipt.reference()
        }
    }
}
