import File_System
import Foundation
import Package_Manager
import Testing

@testable import Institute_Development
@testable import Institute_Model

extension Institute.Xcode.Scheme.Test.Unit {
    @Test
    func `concurrent manifest evaluation preserves specification order`() async throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let application = base.appending(path: "institute-application")
        let institute = base.appending(path: "institute")
        let slow = base.appending(path: "slow")
        let fast = base.appending(path: "fast")
        try Self.package(
            at: institute,
            name: "institute",
            targets: [
                ("Institute Build Coordinator", false),
                ("Institute Model", false),
                ("Institute Inventory", false),
                ("Institute Source Workspace", false), ("Institute Source Profile", false),
                ("Institute Source", false), ("Institute Dependency", false),
                ("Institute Development", false), ("Institute Lint", false),
                ("Institute Pages", false), ("Institute Doctor", false),
                ("Institute Conversion", false), ("Institute Instruments", false),
                ("Institute Tests", true),
                ("Institute Instruments Tests", true),
                ("Institute Development Tests", true),
            ]
        )
        try Self.package(
            at: application,
            name: "institute-application",
            targets: [
                ("Institute Architecture Model", false), ("Institute Architecture Facts", false),
                ("Institute Architecture Graph", false), ("Institute_Architecture_Index", false),
                ("Institute Architecture Validation", false),
                ("Institute_Architecture_Candidates", false),
                ("Institute Architecture Migration", false), ("InstituteArchitectureCLI", false),
                ("Institute GitHub", false), ("Institute Source Application", false),
                ("Institute Application", false), ("Institute Application CLI", false),
                ("InstituteArchitectureTests", true),
                ("Institute Source Application Tests", true),
                ("Institute Application Tests", true),
            ]
        )
        try Self.package(
            at: slow,
            name: "slow",
            targets: [
                ("Source Measurement", false),
                ("Source Profile", false),
                ("Source Execution", false),
                ("Source Report", false),
                ("Source Repair", false),
                ("Institute Linter Rule Manifest", false),
                ("Slow Tests", true),
            ],
            delay: 0.5
        )
        try Self.package(
            at: fast,
            name: "fast",
            targets: [("Fast", false), ("Fast Tests", true)]
        )
        let specification = Institute.Workspace.Specification(members: [
            .init(location: "group:../institute", role: .control(.institute)),
            .init(location: "group:.", role: .control(.application)),
            .init(
                location: "group:../slow",
                role: .subject(
                    try #require(Institute.Repository.Key(identity: "swift-primitives/slow"))
                )
            ),
            .init(
                location: "group:../fast",
                role: .subject(
                    try #require(Institute.Repository.Key(identity: "swift-primitives/fast"))
                )
            ),
        ])
        let root = try Institute.Root(checkout: File.Directory(validating: application.path))

        let plan = try await Institute.Xcode.Scheme.plan(
            for: specification,
            at: root,
            fanout: .init(jobs: 3),
            timeout: .seconds(5)
        )

        #expect(Array(plan.buildables.prefix(13)).allSatisfy { $0.reference == "../institute" })
        #expect(Array(plan.buildables.dropFirst(13).prefix(12)).allSatisfy { $0.reference == "." })
        #expect(
            Array(plan.buildables.dropFirst(25).prefix(6)).allSatisfy { $0.reference == "../slow" })
        #expect(plan.buildables.last?.reference == "../fast")
        #expect(
            plan.testables.map(\.target) == [
                "Institute Tests",
                "Institute Instruments Tests",
                "Institute Development Tests",
                "InstituteArchitectureTests",
                "Institute Source Application Tests",
                "Institute Application Tests",
                "Slow Tests",
                "Fast Tests",
            ])
    }

    @Test
    func `a bounded manifest failure names its workspace member`() async throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let application = base.appending(path: "institute-application")
        let hung = base.appending(path: "hung")
        let executable = base.appending(path: "hang")
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try Self.package(at: hung, name: "hung", targets: [("Hung", false)])
        try Data("#!/bin/sh\nsleep 5\n".utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        let specification = Institute.Workspace.Specification(members: [
            .init(
                location: "group:../hung",
                role: .subject(
                    try #require(Institute.Repository.Key(identity: "swift-primitives/hung"))
                )
            )
        ])
        let root = try Institute.Root(checkout: File.Directory(validating: application.path))

        do throws(Institute.Error) {
            _ = try await Institute.Xcode.Scheme.plan(
                for: specification,
                at: root,
                packages: .init(executable: executable.path),
                fanout: .init(jobs: 1),
                timeout: .milliseconds(50)
            )
            Issue.record("expected bounded manifest evaluation to fail")
        } catch {
            let diagnostic = "\(error)"
            #expect(diagnostic.contains("swift-primitives/hung"))
            #expect(diagnostic.contains("../hung"))
            #expect(diagnostic.contains("timedOut"))
        }
    }
}

extension Institute.Xcode.Scheme.Test.Unit {
    private static func package(
        at directory: URL,
        name: Swift.String,
        targets: [(name: Swift.String, test: Swift.Bool)],
        delay: Swift.Double? = nil
    ) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var declarations = [Swift.String]()
        for (index, target) in targets.enumerated() {
            let path = "\(target.test ? "Tests" : "Sources")/Fixture \(index)"
            let targetDirectory = directory.appending(path: path)
            try FileManager.default.createDirectory(
                at: targetDirectory,
                withIntermediateDirectories: true
            )
            try Data("public enum Fixture\(index) {}\n".utf8).write(
                to: targetDirectory.appending(path: "Fixture.swift")
            )
            declarations.append(
                ".\(target.test ? "testTarget" : "target")"
                    + "(name: \"\(target.name)\", path: \"\(path)\")"
            )
        }
        let pause =
            delay.map {
                "import Foundation\nThread.sleep(forTimeInterval: \($0))"
            } ?? ""
        let manifest = """
            // swift-tools-version: 6.4
            import PackageDescription
            \(pause)

            let package = Package(
                name: "\(name)",
                targets: [
                    \(declarations.joined(separator: ",\n        "))
                ]
            )
            """
        try Data(manifest.utf8).write(to: directory.appending(path: "Package.swift"))
    }
}
