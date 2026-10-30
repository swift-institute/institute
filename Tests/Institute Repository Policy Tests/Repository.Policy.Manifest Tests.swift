import Foundation
import Institute_Model
import Institute_Repository_Policy
import Testing

@Suite
struct `Repository Policy Manifest Tests` {
    static func manifest(depending url: String) -> String {
        """
        // swift-tools-version: 6.0
        import PackageDescription
        let package = Package(
            name: "fixture",
            dependencies: [
                .package(url: "\(url)", branch: "main")
            ]
        )
        """
    }

    static func checkout(_ files: [String: String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "manifest-fixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for (name, text) in files {
            try Data(text.utf8).write(to: root.appending(path: name))
        }
        return root
    }

    @Test
    func `reading collects root manifests in name order and Package.resolved`() throws {
        let root = try Self.checkout([
            "Package@swift-6.0.swift": Self.manifest(depending: "https://github.com/a/swift-y.git"),
            "Package.swift": Self.manifest(depending: "https://github.com/a/swift-x.git"),
            "Package.resolved": "{}",
            "README.md": "not a manifest",
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let manifest = try Institute.Repository.Policy.Manifest.read(at: root.path)

        #expect(manifest.documents.map(\.name) == ["Package.swift", "Package@swift-6.0.swift"])
        #expect(manifest.resolved == "{}")
        #expect(manifest.dependencies.count == 2)
    }

    @Test
    func `an unreadable root is refused`() {
        let missing = FileManager.default.temporaryDirectory
            .appending(path: "manifest-missing-\(UUID().uuidString)").path
        #expect(throws: Institute.Repository.Policy.Manifest.Error.unreadableRoot(missing)) {
            try Institute.Repository.Policy.Manifest.read(at: missing)
        }
    }

    @Test
    func `swift-html-prism is exempt from the identity rule`() {
        let manifest = Institute.Repository.Policy.Manifest(
            documents: [
                .init(
                    name: "Package.swift",
                    source: Self.manifest(depending: "https://github.com/a/swift-x.git")
                ),
                .init(
                    name: "Package@swift-6.0.swift",
                    source: Self.manifest(depending: "https://github.com/b/swift-x.git")
                ),
            ],
            resolved: nil
        )

        #expect(!manifest.identityFindings(repository: "owner/swift-other").isEmpty)
        #expect(manifest.identityFindings(repository: "owner/swift-html-prism").isEmpty)
    }
}
