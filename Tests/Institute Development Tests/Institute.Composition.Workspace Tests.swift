import File_System
import Foundation
import Testing

@testable import Institute_Development
@testable import Institute_Model

extension Institute.Composition.Workspace {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct Integration {}
    }
}

extension Institute.Composition.Workspace.Test.Unit {
    private static func directory(_ path: Swift.String) throws -> File.Directory {
        File.Directory(try File.Path(path))
    }

    @Test
    func `two keyed workspaces produce two distinct generated roots`() throws {
        let base = try Self.directory("/tmp/composition-base")
        let anchor = try Self.directory("/tmp/checkout")
        let one = Institute.Composition.Workspace.keyed("one", under: base, anchor: anchor)
        let two = Institute.Composition.Workspace.keyed("two", under: base, anchor: anchor)
        #expect(one.generatedRoot != two.generatedRoot)
        #expect(one.scratch != two.scratch)
    }

    @Test
    func `a keyed workspace's generated root does not sit below the anchor`() throws {
        let base = try Self.directory("/tmp/composition-base")
        let anchor = try Self.directory("/tmp/checkout")
        let workspace = Institute.Composition.Workspace.keyed("k", under: base, anchor: anchor)
        #expect(!workspace.generatedRoot.path.description.hasPrefix(anchor.path.description))
    }

    @Test
    func `the checkout workspace preserves the legacy generated-root location`() throws {
        let checkout = try Self.directory("/tmp/checkout")
        let workspace = Institute.Composition.Workspace.checkout(checkout)
        #expect(
            workspace.generatedRoot.path.description
                == checkout.path.description + "/institute-composed-root"
        )
    }

    @Test
    func `rebasing under the checkout workspace is the identity, byte for byte`() throws {
        let checkout = try Self.directory("/tmp/checkout")
        let manifests = [
            Institute.Composed.Manifest(
                reference: "../swift-primitives/swift-bit-primitives",
                package: "swift-bit-primitives",
                libraryProducts: ["Bit Primitives"],
                buildableTargetCount: 1
            )
        ]
        let rebased = Institute.Composed.Root.rebased(
            manifests,
            in: .checkout(checkout)
        )
        #expect(rebased == manifests)
    }

    @Test
    func `rebasing for a moved workspace resolves the reference against the anchor`() throws {
        let base = try Self.directory("/tmp/composition-base")
        let anchor = try Self.directory("/tmp/checkout")
        let workspace = Institute.Composition.Workspace.keyed("k", under: base, anchor: anchor)
        let manifests = [
            Institute.Composed.Manifest(
                reference: "../swift-primitives/swift-bit-primitives",
                package: "swift-bit-primitives",
                libraryProducts: ["Bit Primitives"],
                buildableTargetCount: 1
            )
        ]
        let rebased = Institute.Composed.Root.rebased(manifests, in: workspace)
        #expect(rebased.count == 1)
        let reference = try #require(rebased.first).reference
        #expect(reference == "/tmp/checkout/swift-primitives/swift-bit-primitives")
        let resolved = try File.Path(reference)
        #expect(resolved.isAbsolute)
    }
}

extension Institute.Composition.Workspace.Test.Integration {
    private static func temporaryBase() throws -> File.Directory {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return try File.Directory(validating: base.path)
    }

    @Test
    func `concurrent acquisition of one workspace fails deterministically`() throws {
        let base = try Self.temporaryBase()
        defer { try? FileManager.default.removeItem(atPath: base.path.description) }

        let workspace = Institute.Composition.Workspace.keyed("locked", under: base, anchor: base)
        let token = try workspace.acquire()
        #expect(throws: Institute.Error.self) {
            _ = try workspace.acquire()
        }
        token.release()
    }

    @Test
    func `a released workspace can be acquired again`() throws {
        let base = try Self.temporaryBase()
        defer { try? FileManager.default.removeItem(atPath: base.path.description) }

        let workspace = Institute.Composition.Workspace.keyed("cycle", under: base, anchor: base)
        let first = try workspace.acquire()
        first.release()
        let second = try workspace.acquire()
        second.release()
    }

    @Test
    func `distinct workspaces lock independently and share no scratch state`() throws {
        let base = try Self.temporaryBase()
        defer { try? FileManager.default.removeItem(atPath: base.path.description) }

        let one = Institute.Composition.Workspace.keyed("one", under: base, anchor: base)
        let two = Institute.Composition.Workspace.keyed("two", under: base, anchor: base)
        let tokenOne = try one.acquire()
        let tokenTwo = try two.acquire()
        tokenOne.release()
        tokenTwo.release()
        #expect(one.scratch != two.scratch)
        #expect(!one.scratch.path.description.hasPrefix(two.container.path.description))
    }

    @Test
    func `a fresh run receives a fresh execution location without deleting existing state`()
        throws
    {
        let base = try Self.temporaryBase()
        defer { try? FileManager.default.removeItem(atPath: base.path.description) }

        let workspace = Institute.Composition.Workspace.keyed("fresh", under: base, anchor: base)
        let ordinary = workspace.executionLocation(fresh: false)
        #expect(ordinary == workspace.scratch)

        let first = workspace.executionLocation(fresh: true)
        try FileManager.default.createDirectory(
            atPath: first.path.description,
            withIntermediateDirectories: true
        )
        let marker = first.path.description + "/marker"
        FileManager.default.createFile(atPath: marker, contents: Data("state".utf8))

        let second = workspace.executionLocation(fresh: true)
        #expect(second != first)
        #expect(FileManager.default.fileExists(atPath: marker))
    }

    @Test
    func `a written composed root lands inside the workspace container`() throws {
        let base = try Self.temporaryBase()
        defer { try? FileManager.default.removeItem(atPath: base.path.description) }

        let workspace = Institute.Composition.Workspace.keyed("write", under: base, anchor: base)
        try Institute.Composed.Root.write(
            [
                .init(
                    reference: "../swift-primitives/swift-bit-primitives",
                    package: "swift-bit-primitives",
                    libraryProducts: ["Bit Primitives"],
                    buildableTargetCount: 1
                )
            ],
            swift: "6.3.3",
            in: workspace
        )
        let manifest = workspace.generatedRoot[file: "Package.swift"]
        #expect(manifest.stat.exists)
        let bytes = try manifest.read.full { span in
            var storage = [Byte]()
            storage.reserveCapacity(span.count)
            for index in span.indices {
                storage.append(span[index])
            }
            return storage
        }
        let text = Swift.String(decoding: bytes, as: Swift.UTF8.self)
        #expect(text.contains("/swift-primitives/swift-bit-primitives"))
        #expect(!text.contains("\"../swift-primitives"))
    }
}
