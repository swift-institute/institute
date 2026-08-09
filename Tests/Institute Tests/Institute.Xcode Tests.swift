import File_System
import Foundation
import Testing
import Xcode_Workspace_Standard

@testable import Institute_Model
@testable import Institute_Inventory
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Lint
@testable import Institute_Pages
@testable import Institute_Doctor
@testable import Institute_Conversion
@testable import Institute_Instruments

extension Institute.Xcode {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Institute.Xcode.Test.Unit {
    @Test
    func `render terminates the workspace artifact with one line feed`() {
        let rendered = Institute.Xcode.render([])

        #expect(Data(rendered.utf8).last == 0x0A)
        #expect(rendered.hasSuffix("</Workspace>\n"))
    }

    @Test
    func `render uses checkout relative application and sibling hierarchy package references`() {
        let repositories = [
            Institute.Repository(
                name: "swift-example",
                url: "https://github.com/swift-primitives/swift-example.git",
                organization: "swift-primitives",
                layer: .primitives
            ),
            Institute.Repository(
                name: "swift-rfc-0000",
                url: "https://github.com/swift-ietf/swift-rfc-0000.git",
                organization: "swift-ietf",
                layer: .standards
            ),
        ]

        let rendered = Institute.Xcode.render(repositories)
        let document = Institute.Xcode.document(repositories)

        #expect(rendered.contains("group:."))
        #expect(rendered.contains("group:../swift-primitives/swift-example"))
        #expect(rendered.contains("group:../swift-standards/swift-ietf/swift-rfc-0000"))
        #expect(!rendered.contains("/Users/"))
        #expect(!rendered.contains("absolute:"))
        #expect(
            document.references.map(\.location) == [
                .group("."),
                .group("../swift-primitives/swift-example"),
                .group("../swift-standards/swift-ietf/swift-rfc-0000"),
            ]
        )
    }
}

extension Institute.Xcode.Test.Integration {
    @Test
    func `write keeps the generated workspace inside the checkout while references leave for sibling packages`() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let checkout = base.appending(path: "Institute")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
        let root = try File.Directory(validating: checkout.path)
        let repositories = [
            Institute.Repository(
                name: "swift-example",
                url: "https://github.com/swift-foundations/swift-example.git",
                organization: "swift-foundations",
                layer: .foundations
            ),
        ]

        try Institute.Xcode.write(repositories, at: root)

        let generated = checkout.appending(path: "institute.xcworkspace/contents.xcworkspacedata")
        #expect(FileManager.default.fileExists(atPath: generated.path))
        #expect(!FileManager.default.fileExists(atPath: base.appending(path: "institute.xcworkspace").path))
        #expect(try Data(contentsOf: generated) == Data(Institute.Xcode.render(repositories).utf8))
        #expect(Institute.Xcode.current(repositories, at: root))
        #expect(try #require(Institute.Xcode.contents(at: root)).contains("../swift-foundations/swift-example"))

        // Every emitted group must resolve to a directory that actually exists,
        // measured against the filesystem rather than against a literal this
        // test also supplies. The flatten moved the package root out of
        // `Application/` while an expectation pinned the old spelling, so the
        // suite certified a workspace whose first group pointed at a deleted
        // directory. An expectation that restates the value under test cannot
        // catch that; this one can.
        // Group locations are relative to the directory CONTAINING the
        // .xcworkspace bundle, which is the checkout itself.
        try FileManager.default.createDirectory(
            at: base.appending(path: "swift-foundations/swift-example"),
            withIntermediateDirectories: true
        )
        for reference in Institute.Xcode.document(repositories).references {
            guard case .group(let location) = reference.location else {
                Issue.record("unexpected non-group reference \(reference.location)")
                continue
            }
            let resolved = checkout.appending(path: location).standardizedFileURL
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: resolved.path,
                isDirectory: &isDirectory
            )
            #expect(exists && isDirectory.boolValue, "group \(location) resolves to \(resolved.path), which is not a directory")
        }
    }
}
