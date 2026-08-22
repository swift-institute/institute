import File_System
import Foundation
import Testing
import Xcode_Workspace_Standard

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages
@testable import Institute_Source_Workspace

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
    func `workspace membership roles round trip without path inference`() throws {
        let specification = Institute.Workspace.Specification(members: [
            .init(location: "group:.", role: .control(.application)),
            .init(location: "group:../institute", role: .control(.institute)),
            .init(
                location: "group:../institute-continuous-integration",
                role: .control(.continuousIntegration)
            ),
            .init(
                location: "group:../swift-primitives/swift-example",
                role: .subject(
                    try #require(
                        Institute.Repository.Key(identity: "swift-primitives/swift-example")
                    )
                )
            ),
        ])

        let decoded = try Institute.Workspace.Specification(
            jsonString: specification.jsonString(sortKeys: true)
        )

        #expect(decoded == specification)
    }

    @Test
    func `render terminates the workspace artifact with one line feed`() throws {
        let rendered = try Institute.Xcode.render(
            .init(members: [
                .init(location: "group:.", role: .control(.application))
            ])
        )

        #expect(Data(rendered.utf8).last == 0x0A)
        #expect(rendered.hasSuffix("</Workspace>\n"))
    }

    @Test
    func `render uses sibling hierarchy package references`() {
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

        let specification = try Institute.Xcode.specification(repositories)
        let rendered = try Institute.Xcode.render(specification)
        let document = try Institute.Xcode.document(specification)

        #expect(specification.members.count == repositories.count)
        #expect(
            specification.members.allSatisfy { member in
                if case .subject = member.role { true } else { false }
            }
        )
        #expect(rendered.contains("group:../swift-primitives/swift-example"))
        #expect(rendered.contains("group:../swift-standards/swift-ietf/swift-rfc-0000"))
        #expect(!rendered.contains("/Users/"))
        #expect(!rendered.contains("absolute:"))
        #expect(
            document.references.map(\.location) == [
                .group("../swift-primitives/swift-example"),
                .group("../swift-standards/swift-ietf/swift-rfc-0000"),
            ]
        )
    }
}

extension Institute.Xcode.Test.Integration {
    @Test
    func
        `write keeps the generated workspace inside the checkout while references leave for sibling packages`()
        throws
    {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let checkout = base.appending(path: "institute-application")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
        let root = try File.Directory(validating: checkout.path)
        let repositories = [
            Institute.Repository(
                name: "swift-example",
                url: "https://github.com/swift-foundations/swift-example.git",
                organization: "swift-foundations",
                layer: .foundations
            )
        ]

        let specification = try Institute.Xcode.specification(repositories)
        try Institute.Xcode.write(specification, at: root)

        let generated = checkout.appending(
            path: "institute interim.xcworkspace/contents.xcworkspacedata"
        )
        #expect(FileManager.default.fileExists(atPath: generated.path))
        #expect(
            !FileManager.default.fileExists(
                atPath: base.appending(path: "institute.xcworkspace").path
            )
        )
        #expect(
            try Data(contentsOf: generated) == Data(Institute.Xcode.render(specification).utf8)
        )
        #expect(Institute.Xcode.current(specification, at: root))
        #expect(
            try #require(Institute.Xcode.contents(at: root)).contains(
                "../swift-foundations/swift-example"
            )
        )

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
        for reference in try Institute.Xcode.document(specification).references {
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
            #expect(
                exists && isDirectory.boolValue,
                "group \(location) resolves to \(resolved.path), which is not a directory"
            )
        }
    }

    @Test
    func `typed controls remain outside inventory admission and enter measurement`() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let application = base.appending(path: "institute-application")
        defer { try? FileManager.default.removeItem(at: base) }
        for directory in [
            application,
            base.appending(path: "institute"),
            base.appending(path: "institute-continuous-integration"),
            base.appending(path: "swift-primitives/swift-example"),
        ] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try Data("// swift-tools-version: 6.4\n".utf8).write(
                to: directory.appending(path: "Package.swift")
            )
        }
        let repository = Institute.Repository(
            name: "swift-example",
            url: "https://github.com/swift-primitives/swift-example.git",
            organization: "swift-primitives",
            layer: .primitives
        )
        let root = try Institute.Root(checkout: File.Directory(validating: application.path))
        let specification = Institute.Workspace.Specification(members: [
            .init(location: "group:.", role: .control(.application)),
            .init(location: "group:../institute", role: .control(.institute)),
            .init(
                location: "group:../institute-continuous-integration",
                role: .control(.continuousIntegration)
            ),
            .init(
                location: "group:../swift-primitives/swift-example",
                role: .subject(
                    try #require(
                        Institute.Repository.Key(identity: "swift-primitives/swift-example")
                    )
                )
            ),
        ])
        try Institute.Xcode.write(specification, at: root.checkout)
        let configuration = Institute.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.4.0",
            xcode: "27.0",
            repositories: [repository]
        )

        let cohort = try Institute.Source.Workspace.Cohort.read(
            from: Institute.Xcode.bundle(at: root.checkout).description,
            configuration: configuration,
            hierarchy: root.hierarchy
        )

        #expect(cohort.references == 4)
        #expect(
            cohort.controls.map(\.identity) == [
                "control:application",
                "control:institute",
                "control:continuous-integration",
            ]
        )
        #expect(cohort.admitted.map(\.identity) == ["swift-primitives/swift-example"])
        #expect(
            cohort.measurable.map(\.identity) == [
                "control:application",
                "control:institute",
                "control:continuous-integration",
                "swift-primitives/swift-example",
            ]
        )
        #expect(cohort.reasons.isEmpty)
    }
}
