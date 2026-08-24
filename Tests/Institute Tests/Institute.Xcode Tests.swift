import File_System
import Foundation
import JSON
import Source_Measurement
import Synchronization
import Testing
import Xcode_Workspace
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
    func `materialization keeps input commitment separate from artifact digests`() throws {
        let member = Institute.Workspace.Member(
            location: "group:../institute",
            role: .control(.institute)
        )
        let input = Institute.Workspace.Materialization.Input(
            dependency: .localInstituteClosure,
            toolchain: Swift.String(repeating: "a", count: 64),
            packages: [
                .init(
                    member: member,
                    reference: "../institute",
                    manifest: Swift.String(repeating: "b", count: 64),
                    sources: [
                        .init(
                            path: "Sources/Institute.swift",
                            kind: .swift,
                            purpose: .governedSource,
                            provenance: .authored,
                            digest: .init(Swift.String(repeating: "c", count: 64))
                        )
                    ]
                )
            ]
        )
        let first = Institute.Workspace.Materialization.Receipt(
            input: input,
            artifacts: [
                .init(
                    name: "scheme",
                    path: "Institute.xcscheme",
                    digest: Institute.Workspace.Materialization.digest("first")
                )
            ],
            buildables: [.init(reference: "../institute", name: "Institute Model")],
            testables: .init(
                values: [.init(reference: "../institute", name: "Institute Tests")]
            )
        )
        let second = Institute.Workspace.Materialization.Receipt(
            input: input,
            artifacts: [
                .init(
                    name: "scheme",
                    path: "Institute.xcscheme",
                    digest: Institute.Workspace.Materialization.digest("second")
                )
            ],
            buildables: first.buildables,
            testables: first.testables
        )

        #expect(first.input.digest == second.input.digest)
        #expect(first.input.dependency == .localInstituteClosure)
        #expect(first.artifacts.map(\.digest) != second.artifacts.map(\.digest))
        let changedDependency = Institute.Workspace.Materialization.Input(
            dependency: .remoteAllowed,
            toolchain: input.toolchain,
            packages: input.packages
        )
        #expect(input.digest != changedDependency.digest)
        let changedSource = Institute.Workspace.Materialization.Input(
            dependency: input.dependency,
            toolchain: input.toolchain,
            packages: [
                .init(
                    member: member,
                    reference: "../institute",
                    manifest: Swift.String(repeating: "b", count: 64),
                    sources: [
                        .init(
                            path: "Sources/Institute.swift",
                            kind: .swift,
                            purpose: .governedSource,
                            provenance: .authored,
                            digest: .init(Swift.String(repeating: "d", count: 64))
                        )
                    ]
                )
            ]
        )
        #expect(input.digest != changedSource.digest)
        #expect(
            try Institute.Workspace.Materialization.Receipt(
                jsonString: first.jsonString(sortKeys: true))
                == first
        )
    }

    private struct PublicationState: Sendable {
        var files: [Swift.String: Swift.String]
        var writes = 0
        var failed = false
    }

    @Test
    func `publication restores every preimage when one document cannot be written`() throws {
        let directory = try File.Directory(
            validating: FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString).path
        )
        let documents = ["workspace", "membership", "scheme"].map { name in
            Institute.Xcode.Publication.Document(
                file: directory[file: name],
                contents: "new-\(name)"
            )
        }
        let initial = Dictionary(
            uniqueKeysWithValues: documents.map {
                ($0.file.description, "old-\($0.file.description)")
            }
        )
        let state = Mutex(PublicationState(files: initial))
        let client = Institute.Xcode.Publication.Client(
            read: { file in state.withLock { $0.files[file.description] } },
            write: { file, contents throws(Institute.Error) in
                do {
                    try state.withLock { state throws(Institute.Error) in
                        if !state.failed && state.writes == 1 {
                            state.failed = true
                            throw .filesystem("injected publication failure")
                        }
                        state.writes += 1
                        state.files[file.description] = contents
                    }
                } catch let error as Institute.Error {
                    throw error
                } catch {
                    throw Institute.Error.filesystem(
                        "unexpected publication fixture failure: \(error)"
                    )
                }
            },
            delete: { file in state.withLock { _ = $0.files.removeValue(forKey: file.description) }
            }
        )
        let publication = try Institute.Xcode.Publication(documents: documents)

        #expect(throws: Institute.Error.self) {
            try publication.apply(client: client)
        }
        #expect(state.withLock { $0.files } == initial)
    }

    @Test
    func `workspace membership roles round trip without path inference`() throws {
        let specification = Institute.Workspace.Specification(
            dependency: .localInstituteClosure,
            members: [
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
            ]
        )

        let decoded = try Institute.Workspace.Specification(
            jsonString: specification.jsonString(sortKeys: true)
        )

        #expect(decoded == specification)
        #expect(decoded.dependency == .localInstituteClosure)
    }

    @Test
    func `local closure reports every missing Institute dependency in identity order`() throws {
        let selected = Self.repository(owner: "swift-foundations", name: "swift-selected")
        let first = Self.repository(owner: "swift-primitives", name: "swift-first")
        let second = Self.repository(owner: "swift-foundations", name: "swift-second")
        let specification = Self.specification(
            dependency: .localInstituteClosure,
            repositories: [selected]
        )
        let configuration = Self.configuration([selected, first, second])

        do throws(Institute.Error) {
            try Institute.Workspace.Materialization.validate(
                specification: specification,
                catalog: Self.catalog(specification, dependencies: [first.url]),
                configuration: configuration
            )
            Issue.record("expected one missing Institute dependency")
        } catch {
            #expect(
                error.description
                    == "workspace local Institute dependency closure is incomplete; missing: "
                    + "[swift-primitives/swift-first]"
            )
        }

        do throws(Institute.Error) {
            try Institute.Workspace.Materialization.validate(
                specification: specification,
                catalog: Self.catalog(
                    specification,
                    dependencies: [first.url, second.url]
                ),
                configuration: configuration
            )
            Issue.record("expected two missing Institute dependencies")
        } catch {
            #expect(
                error.description
                    == "workspace local Institute dependency closure is incomplete; missing: "
                    + "[swift-foundations/swift-second, swift-primitives/swift-first]"
            )
        }
    }

    @Test
    func `local closure admits selected Institute dependencies and external remotes`() throws {
        let selected = Self.repository(owner: "swift-foundations", name: "swift-selected")
        let dependency = Self.repository(owner: "swift-primitives", name: "swift-dependency")
        let specification = Self.specification(
            dependency: .localInstituteClosure,
            repositories: [selected, dependency]
        )

        try Institute.Workspace.Materialization.validate(
            specification: specification,
            catalog: Self.catalog(
                specification,
                dependencies: [
                    dependency.url,
                    "https://github.com/external/swift-external.git",
                ]
            ),
            configuration: Self.configuration([selected, dependency])
        )
    }

    @Test
    func `dependency binding rather than a workspace name selects closure enforcement`() throws {
        let selected = Self.repository(owner: "swift-foundations", name: "swift-selected")
        let dependency = Self.repository(owner: "swift-primitives", name: "swift-dependency")
        let local = Self.specification(
            dependency: .localInstituteClosure,
            repositories: [selected]
        )
        let remote = Self.specification(
            dependency: .remoteAllowed,
            repositories: [selected]
        )
        let configuration = Self.configuration([selected, dependency])
        let catalog = Self.catalog(remote, dependencies: [dependency.url])

        try Institute.Workspace.Materialization.validate(
            specification: remote,
            catalog: catalog,
            configuration: configuration
        )
        #expect(throws: Institute.Error.self) {
            try Institute.Workspace.Materialization.validate(
                specification: local,
                catalog: catalog,
                configuration: configuration
            )
        }
    }

    @Test
    func `render terminates the workspace artifact with one line feed`() throws {
        let rendered = try Institute.Xcode.render(
            .init(dependency: .remoteAllowed, members: [
                .init(location: "group:.", role: .control(.application))
            ])
        )

        #expect(Data(rendered.utf8).last == 0x0A)
        #expect(rendered.hasSuffix("</Workspace>\n"))
    }

    @Test
    func `render uses sibling hierarchy package references`() throws {
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
        let locations = document.references.compactMap { reference in
            if case .file(let location) = reference { location } else { nil }
        }
        #expect(locations.count == document.references.count)
        #expect(
            locations.map(\.rawValue) == [
                "group:../swift-primitives/swift-example",
                "group:../swift-standards/swift-ietf/swift-rfc-0000",
            ]
        )
    }

    @Test
    func `integration composes both self-hosting controls without changing the subject cohort`()
        throws
    {
        let repositories = [
            Institute.Repository(
                name: "swift-example",
                url: "https://github.com/swift-primitives/swift-example.git",
                organization: "swift-primitives",
                layer: .primitives
            )
        ]

        let generic = try Institute.Xcode.specification(repositories)
        let integration = try Institute.Xcode.integration(repositories)

        #expect(
            generic.members.map(\.role).allSatisfy { role in
                if case .subject = role { true } else { false }
            })
        #expect(integration.members.first?.location == "group:../institute")
        #expect(integration.members.first?.role == .control(.institute))
        #expect(integration.members[1].location == "group:.")
        #expect(integration.members[1].role == .control(.application))
        #expect(
            integration.members.compactMap { member in
                if case .subject(let repository) = member.role { repository } else { nil }
            }
                == generic.members.compactMap { member in
                    if case .subject(let repository) = member.role { repository } else { nil }
                }
        )
    }

    @Test
    func `workspace integration preserves exact structural member order`() throws {
        let workspace = Xcode_Workspace.Xcode.Workspace(
            references: [
                .file(.init(scheme: .group, path: ".")),
                .file(.init(scheme: .group, path: "../institute")),
            ]
        )

        let specification = try Institute.Xcode.integration(workspace, repositories: [])

        #expect(specification.members.map(\.location) == ["group:.", "group:../institute"])
        #expect(specification.members.map(\.role) == [.control(.application), .control(.institute)])
    }

    @Test
    func `workspace integration fails closed for an unowned reference`() throws {
        let workspace = Xcode_Workspace.Xcode.Workspace(
            references: [.file(.init(scheme: .group, path: "../unknown"))]
        )

        #expect(throws: Institute.Error.self) {
            _ = try Institute.Xcode.integration(workspace, repositories: [])
        }
    }
}

extension Institute.Xcode.Test.Unit {
    private static func repository(
        owner: Swift.String,
        name: Swift.String
    ) -> Institute.Repository {
        .init(
            name: name,
            url: "https://github.com/\(owner)/\(name).git",
            organization: owner,
            layer: owner == "swift-primitives" ? .primitives : .foundations
        )
    }

    private static func configuration(
        _ repositories: [Institute.Repository]
    ) -> Institute.Configuration {
        .init(
            version: 1,
            scope: "swift-institute",
            swift: "6.4.0",
            xcode: "27.0",
            repositories: repositories
        )
    }

    private static func specification(
        dependency: Institute.Workspace.Dependency.Binding,
        repositories: [Institute.Repository]
    ) -> Institute.Workspace.Specification {
        .init(
            dependency: dependency,
            members: repositories.compactMap { repository in
                Institute.Repository.Key(repository: repository).map { key in
                    .init(
                        location: "group:../\(repository.organization)/\(repository.name)",
                        role: .subject(key)
                    )
                }
            }
        )
    }

    private static func catalog(
        _ specification: Institute.Workspace.Specification,
        dependencies: [Swift.String]
    ) -> Institute.Xcode.Catalog {
        .init(
            entries: specification.members.enumerated().map { index, member in
                .init(
                    member: member,
                    reference: "../fixture-\(index)",
                    manifest: Swift.String(repeating: "a", count: 64),
                    toolchain: Swift.String(repeating: "b", count: 64),
                    dependencies: index == 0 ? dependencies : [],
                    targets: [],
                    sources: []
                )
            }
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
            guard case .file(let location) = reference, location.scheme == .group else {
                Issue.record("unexpected non-group file reference \(reference)")
                continue
            }
            let resolved = checkout.appending(path: location.path).standardizedFileURL
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
        let specification = Institute.Workspace.Specification(dependency: .remoteAllowed, members: [
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
