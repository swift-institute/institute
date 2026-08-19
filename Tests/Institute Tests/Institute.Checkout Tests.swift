import File_System
import Foundation
import Git_Foundation
import Testing

@testable import Institute_Development
@testable import Institute_Model

extension Institute.Checkout {
    @Suite
    struct Test {
        @Test
        func `exact commit materializes, verifies, and is destination-independent`() throws {
            let fixture = try Fixture()
            defer { fixture.remove() }

            let first = try fixture.commit("first", contents: "first\n")
            let second = try fixture.commit("second", contents: "second\n")

            let checkout = Institute.Checkout(client: fixture.client)
            let one = try checkout.materialize(
                url: fixture.source.path,
                revision: first,
                to: fixture.destination("one")
            )
            let two = try checkout.materialize(
                url: fixture.source.path,
                revision: first,
                to: fixture.destination("two")
            )

            // Canonical evidence is identity, not location: two
            // materializations of one commit agree on revision and tree.
            #expect(one.revision == first)
            #expect(one.revision == two.revision)
            #expect(one.tree == two.tree)
            #expect(one.directory != two.directory)

            // The materialized bytes are the commit's, not the source's
            // current state (the source has advanced to `second`).
            #expect(try fixture.client.head(at: fixture.source.path) == second)
            #expect(
                try Swift.String(
                    contentsOf: fixture.destination("one")
                        .url.appending(path: "Fixture.txt"),
                    encoding: .utf8
                ) == "first\n"
            )
        }

        @Test
        func `developer worktree state cannot reach the materialized tree`() throws {
            let fixture = try Fixture()
            defer { fixture.remove() }

            let commit = try fixture.commit("committed", contents: "committed\n")

            // Dirty the source's worktree in every uncommitted way: a
            // modified tracked file, a staged-but-uncommitted file, an
            // untracked manifest, and a deleted tracked file.
            try fixture.write("Fixture.txt", contents: "modified, never committed\n")
            try fixture.write("Staged.swift", contents: "staged, never committed\n")
            try fixture.command(["add", "Staged.swift"])
            try fixture.write("Package.swift", contents: "// untracked manifest\n")
            try fixture.command(["rm", "--cached", "Fixture.txt"])

            let checkout = Institute.Checkout(client: fixture.client)
            let materialized = try checkout.materialize(
                url: fixture.source.path,
                revision: commit,
                to: fixture.destination("clean")
            )

            #expect(materialized.revision == commit)
            let root = fixture.destination("clean").url
            #expect(
                try Swift.String(
                    contentsOf: root.appending(path: "Fixture.txt"),
                    encoding: .utf8
                ) == "committed\n"
            )
            #expect(
                !FileManager.default.fileExists(
                    atPath: root.appending(path: "Staged.swift").path
                )
            )
            #expect(
                !FileManager.default.fileExists(
                    atPath: root.appending(path: "Package.swift").path
                )
            )
        }

        @Test
        func `a moving source cannot change a selected materialization`() throws {
            let fixture = try Fixture()
            defer { fixture.remove() }

            let selected = try fixture.commit("selected", contents: "selected\n")
            // The source's branch moves after selection.
            _ = try fixture.commit("later", contents: "later\n")

            let checkout = Institute.Checkout(client: fixture.client)
            let materialized = try checkout.materialize(
                url: fixture.source.path,
                revision: selected,
                to: fixture.destination("frozen")
            )
            #expect(materialized.revision == selected)
            #expect(
                try Swift.String(
                    contentsOf: fixture.destination("frozen").url.appending(path: "Fixture.txt"),
                    encoding: .utf8
                ) == "selected\n"
            )
        }

        @Test
        func `a missing object fails before anything is published`() throws {
            let fixture = try Fixture()
            defer { fixture.remove() }

            _ = try fixture.commit("only", contents: "only\n")
            let absent = try #require(
                Git.Object.ID(rawValue: Swift.String(repeating: "a", count: 40))
            )

            let checkout = Institute.Checkout(client: fixture.client)
            #expect(throws: Institute.Error.self) {
                try checkout.materialize(
                    url: fixture.source.path,
                    revision: absent,
                    to: fixture.destination("never")
                )
            }
            #expect(!FileManager.default.fileExists(atPath: fixture.destination("never").url.path))
        }

        @Test
        func `an existing destination is refused, never overwritten`() throws {
            let fixture = try Fixture()
            defer { fixture.remove() }

            let commit = try fixture.commit("only", contents: "only\n")
            let destination = fixture.destination("occupied")
            try FileManager.default.createDirectory(
                at: destination.url,
                withIntermediateDirectories: true
            )
            let sentinel = destination.url.appending(path: "Sentinel.txt")
            try "keep\n".write(to: sentinel, atomically: true, encoding: .utf8)

            let checkout = Institute.Checkout(client: fixture.client)
            #expect(throws: Institute.Error.self) {
                try checkout.materialize(
                    url: fixture.source.path,
                    revision: commit,
                    to: destination
                )
            }
            #expect(try Swift.String(contentsOf: sentinel, encoding: .utf8) == "keep\n")
        }

        @Test
        func `materialization leaves the source repository untouched`() throws {
            let fixture = try Fixture()
            defer { fixture.remove() }

            let commit = try fixture.commit("committed", contents: "committed\n")
            try fixture.write("Dirty.txt", contents: "uncommitted work\n")
            let before = try fixture.client.status(at: fixture.source.path)
            #expect(!before.isEmpty)

            let checkout = Institute.Checkout(client: fixture.client)
            _ = try checkout.materialize(
                url: fixture.source.path,
                revision: commit,
                to: fixture.destination("readonly")
            )

            #expect(try fixture.client.status(at: fixture.source.path) == before)
            #expect(try fixture.client.head(at: fixture.source.path) == commit)
        }

        @Test
        func `symlinks and executable modes survive materialization`() throws {
            let fixture = try Fixture()
            defer { fixture.remove() }

            try fixture.write("Target.txt", contents: "target\n")
            try fixture.command(["add", "Target.txt"])
            let link = fixture.source.appending(path: "Link")
            try FileManager.default.createSymbolicLink(
                at: link,
                withDestinationURL: URL(fileURLWithPath: "Target.txt")
            )
            let script = fixture.source.appending(path: "Script.sh")
            try "#!/bin/sh\n".write(to: script, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: script.path
            )
            try fixture.command(["add", "Link", "Script.sh"])
            try fixture.command(["commit", "-m", "shapes"])
            let commit = try fixture.client.head(at: fixture.source.path)

            let checkout = Institute.Checkout(client: fixture.client)
            _ = try checkout.materialize(
                url: fixture.source.path,
                revision: commit,
                to: fixture.destination("shapes")
            )

            let root = fixture.destination("shapes").url
            let attributes = try FileManager.default.attributesOfItem(
                atPath: root.appending(path: "Link").path
            )
            #expect(attributes[.type] as? FileAttributeType == .typeSymbolicLink)
            let permissions =
                try FileManager.default.attributesOfItem(
                    atPath: root.appending(path: "Script.sh").path
                )[.posixPermissions] as? Swift.Int
            #expect((permissions ?? 0) & 0o100 != 0)
        }

        @Test
        func `a submodule-declaring revision is refused for a typed reason`() throws {
            let fixture = try Fixture()
            defer { fixture.remove() }

            _ = try fixture.commit("first", contents: "first\n")
            try fixture.write(".gitmodules", contents: "[submodule \"x\"]\n\tpath = x\n")
            try fixture.command(["add", ".gitmodules"])
            try fixture.command(["commit", "-m", "modules"])
            let commit = try fixture.client.head(at: fixture.source.path)

            let checkout = Institute.Checkout(client: fixture.client)
            #expect(throws: Institute.Error.self) {
                try checkout.materialize(
                    url: fixture.source.path,
                    revision: commit,
                    to: fixture.destination("modules")
                )
            }
            #expect(
                !FileManager.default.fileExists(
                    atPath: fixture.destination("modules").url.path
                )
            )
        }
    }
}

extension Institute.Checkout.Test {
    /// One temporary source repository plus a family of destination paths,
    /// removed together.
    struct Fixture {
        let base: URL
        let source: URL
        let client: Git.Client

        init() throws {
            base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            source = base.appending(path: "source")
            client = .init()
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
            try client.initialize(at: source.path, bare: false)
            try command(["config", "user.email", "workspace@swift.institute"])
            try command(["config", "user.name", "Institute Tests"])
            try command(["branch", "-M", "main"])
        }

        func remove() {
            // swift-linter:disable:next try optional
            // REASON: Foundation.FileManager.removeItem(at:) is an untyped cross-module throwing API.
            try? FileManager.default.removeItem(at: base)
        }

        func destination(_ name: Swift.String) -> File.Directory {
            .init(File.Path("\(base.path)/destinations/\(name)"))
        }

        func write(_ name: Swift.String, contents: Swift.String) throws {
            try contents.write(
                to: source.appending(path: name),
                atomically: true,
                encoding: .utf8
            )
        }

        func command(_ arguments: [Swift.String]) throws {
            let process = Foundation.Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments
            process.currentDirectoryURL = source
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw CocoaError(.executableNotLoadable)
            }
        }

        func commit(
            _ message: Swift.String,
            contents: Swift.String
        ) throws -> Git.Object.ID {
            try write("Fixture.txt", contents: contents)
            try command(["add", "Fixture.txt"])
            try command(["commit", "-m", message])
            return try client.head(at: source.path)
        }
    }
}

extension File.Directory {
    fileprivate var url: URL {
        URL(fileURLWithPath: description, isDirectory: true)
    }
}
