import File_System
import Package_Manager
import Testing

@testable import Institute_Development
@testable import Institute_Model

extension Institute.Xcode.Scheme.Test.Unit {
    @Test
    func `concurrent manifest evaluation preserves specification order`() async throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        defer { try? MainFixtureFiles.remove(base) }
        let application = MainFixtureFiles.join(base, "institute-application")
        let institute = MainFixtureFiles.join(base, "institute")
        let slow = MainFixtureFiles.join(base, "slow")
        let fast = MainFixtureFiles.join(base, "fast")
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
                ("Institute CI Canon", false), ("Institute CI Contract", false),
                ("Institute CI Inventory", false), ("Institute CI Model", false),
                ("Institute CI Validation", false), ("Institute CI Workflow", false),
                ("Institute Repository Policy", false), ("Institute Source Policy", false),
                ("Institute Tests", true),
                ("Institute Instruments Tests", true),
                ("Institute Development Tests", true),
                ("Institute CI Canon Tests", true),
                ("Institute CI Inventory Tests", true),
                ("Institute CI Model Tests", true),
                ("Institute CI Validation Tests", true),
                ("Institute CI Workflow Tests", true),
                ("Institute Source Policy Tests", true),
            ]
        )
        try Self.package(
            at: application,
            name: "institute-application",
            targets: [
                ("Institute Application", false), ("Institute CI Application", false),
                ("Institute Application CLI", false),
                ("Institute Certification Application", false),
                ("Institute Coherence Application", false),
                ("Institute Composition Application", false),
                ("Institute Context Application", false),
                ("Institute Conversion Application", false),
                ("Institute Dependency Application", false),
                ("Institute Doctor Application", false),
                ("Institute GitHub Application", false),
                ("Institute Inventory Application", false),
                ("Institute Navigation Application", false),
                ("Institute Package Application", false),
                ("Institute Repository Application", false),
                ("Institute Source Application", false),
                ("Institute Verification Application", false),
                ("Institute Workspace Application", false),
                ("Institute Architecture CLI", false),
                ("Institute Architecture Candidates", false),
                ("Institute Architecture Facts", false),
                ("Institute Architecture Graph", false),
                ("Institute Architecture Index", false),
                ("Institute Architecture Migration", false),
                ("Institute Architecture Model", false),
                ("Institute Architecture Validation", false),
                ("Institute GitHub", false),
                ("Institute CI Application Tests", true),
                ("Institute Repository Application Tests", true),
                ("Institute Source Application Tests", true),
                ("Institute Application Tests", true),
                ("Institute Architecture Tests", true),
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
        let specification = Institute.Workspace.Specification(dependency: .remoteAllowed, members: [
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
        let root = try Institute.Root(checkout: File.Directory(validating: application))

        let plan = try await Institute.Xcode.Scheme.plan(
            for: specification,
            at: root,
            fanout: .init(jobs: 3),
            timeout: .seconds(5)
        )

        #expect(Array(plan.buildables.prefix(21)).allSatisfy { $0.reference == "../institute" })
        #expect(Array(plan.buildables.dropFirst(21).prefix(27)).allSatisfy { $0.reference == "." })
        #expect(
            Array(plan.buildables.dropFirst(48).prefix(6)).allSatisfy { $0.reference == "../slow" })
        #expect(plan.buildables.last?.reference == "../fast")
        #expect(
            plan.testables.map(\.target) == [
                "Institute Tests",
                "Institute Instruments Tests",
                "Institute Development Tests",
                "Institute CI Canon Tests",
                "Institute CI Inventory Tests",
                "Institute CI Model Tests",
                "Institute CI Validation Tests",
                "Institute CI Workflow Tests",
                "Institute Source Policy Tests",
                "Institute CI Application Tests",
                "Institute Repository Application Tests",
                "Institute Source Application Tests",
                "Institute Application Tests",
                "Institute Architecture Tests",
                "Slow Tests",
                "Fast Tests",
            ])
    }

    @Test
    func `a bounded manifest failure names its workspace member`() async throws {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        defer { try? MainFixtureFiles.remove(base) }
        let application = MainFixtureFiles.join(base, "institute-application")
        let hung = MainFixtureFiles.join(base, "hung")
        let executable = MainFixtureFiles.join(base, "hang")
        try MainFixtureFiles.createDirectory(application)
        try Self.package(at: hung, name: "hung", targets: [("Hung", false)])
        try MainFixtureFiles.write(bytes: Array("#!/bin/sh\nsleep 5\n".utf8), to: executable)
        try MainFixtureFiles.setPermissions(executable, posix: 0o755)
        let specification = Institute.Workspace.Specification(dependency: .remoteAllowed, members: [
            .init(
                location: "group:../hung",
                role: .subject(
                    try #require(Institute.Repository.Key(identity: "swift-primitives/hung"))
                )
            )
        ])
        let root = try Institute.Root(checkout: File.Directory(validating: application))

        do throws(Institute.Error) {
            _ = try await Institute.Xcode.Scheme.plan(
                for: specification,
                at: root,
                packages: .init(executable: executable),
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
        at directory: Swift.String,
        name: Swift.String,
        targets: [(name: Swift.String, test: Swift.Bool)],
        delay: Swift.Double? = nil
    ) throws {
        try MainFixtureFiles.createDirectory(directory)
        var declarations = [Swift.String]()
        for (index, target) in targets.enumerated() {
            let path = "\(target.test ? "Tests" : "Sources")/Fixture \(index)"
            let targetDirectory = MainFixtureFiles.join(directory, path)
            try MainFixtureFiles.createDirectory(targetDirectory)
            try MainFixtureFiles.write(
                bytes: Array("public enum Fixture\(index) {}\n".utf8),
                to: MainFixtureFiles.join(targetDirectory, "Fixture.swift")
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
        try MainFixtureFiles.write(bytes: Array(manifest.utf8), to: MainFixtureFiles.join(directory, "Package.swift"))
    }
}
