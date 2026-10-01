import File_System
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
                url: fixture.source,
                revision: first,
                to: fixture.destination("one")
            )
            let two = try checkout.materialize(
                url: fixture.source,
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
            #expect(try fixture.client.head(at: fixture.source) == second)
            #expect(
                try MainFixtureFiles.readStrictUTF8URL(
                    MainFixtureFiles.join(fixture.destination("one").url, "Fixture.txt")
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
                url: fixture.source,
                revision: commit,
                to: fixture.destination("clean")
            )

            #expect(materialized.revision == commit)
            let root = fixture.destination("clean").url
            #expect(
                try MainFixtureFiles.readStrictUTF8URL(MainFixtureFiles.join(root, "Fixture.txt")) == "committed\n"
            )
            #expect(
                !MainFixtureFiles.exists(MainFixtureFiles.join(root, "Staged.swift"))
            )
            #expect(
                !MainFixtureFiles.exists(MainFixtureFiles.join(root, "Package.swift"))
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
                url: fixture.source,
                revision: selected,
                to: fixture.destination("frozen")
            )
            #expect(materialized.revision == selected)
            #expect(
                try MainFixtureFiles.readStrictUTF8URL(MainFixtureFiles.join(fixture.destination("frozen").url, "Fixture.txt")) == "selected\n"
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
                    url: fixture.source,
                    revision: absent,
                    to: fixture.destination("never")
                )
            }
            #expect(!MainFixtureFiles.exists(fixture.destination("never").url))
        }

        @Test
        func `an existing destination is refused, never overwritten`() throws {
            let fixture = try Fixture()
            defer { fixture.remove() }

            let commit = try fixture.commit("only", contents: "only\n")
            let destination = fixture.destination("occupied")
            try MainFixtureFiles.createDirectory(destination.url)
            let sentinel = MainFixtureFiles.join(destination.url, "Sentinel.txt")
            try MainFixtureFiles.write("keep\n", toURLPath: sentinel)

            let checkout = Institute.Checkout(client: fixture.client)
            #expect(throws: Institute.Error.self) {
                try checkout.materialize(
                    url: fixture.source,
                    revision: commit,
                    to: destination
                )
            }
            #expect(try MainFixtureFiles.readStrictUTF8URL(sentinel) == "keep\n")
        }

        @Test
        func `materialization leaves the source repository untouched`() throws {
            let fixture = try Fixture()
            defer { fixture.remove() }

            let commit = try fixture.commit("committed", contents: "committed\n")
            try fixture.write("Dirty.txt", contents: "uncommitted work\n")
            let before = try fixture.client.status(at: fixture.source)
            #expect(!before.isEmpty)

            let checkout = Institute.Checkout(client: fixture.client)
            _ = try checkout.materialize(
                url: fixture.source,
                revision: commit,
                to: fixture.destination("readonly")
            )

            #expect(try fixture.client.status(at: fixture.source) == before)
            #expect(try fixture.client.head(at: fixture.source) == commit)
        }

        @Test
        func `symlinks and executable modes survive materialization`() throws {
            let fixture = try Fixture()
            defer { fixture.remove() }

            try fixture.write("Target.txt", contents: "target\n")
            try fixture.command(["add", "Target.txt"])
            let link = MainFixtureFiles.join(fixture.source, "Link")
            try MainFixtureFiles.createSymbolicLink(link, toURLOf: "Target.txt")
            let script = MainFixtureFiles.join(fixture.source, "Script.sh")
            try MainFixtureFiles.write("#!/bin/sh\n", toURLPath: script)
            try MainFixtureFiles.setPermissions(script, posix: 0o755)
            try fixture.command(["add", "Link", "Script.sh"])
            try fixture.command(["commit", "-m", "shapes"])
            let commit = try fixture.client.head(at: fixture.source)

            let checkout = Institute.Checkout(client: fixture.client)
            _ = try checkout.materialize(
                url: fixture.source,
                revision: commit,
                to: fixture.destination("shapes")
            )

            let root = fixture.destination("shapes").url
            #expect(try MainFixtureFiles.isSymbolicLink(MainFixtureFiles.join(root, "Link")))
            let permissions = try MainFixtureFiles.posixPermissions(MainFixtureFiles.join(root, "Script.sh"))
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
            let commit = try fixture.client.head(at: fixture.source)

            let checkout = Institute.Checkout(client: fixture.client)
            #expect(throws: Institute.Error.self) {
                try checkout.materialize(
                    url: fixture.source,
                    revision: commit,
                    to: fixture.destination("modules")
                )
            }
            #expect(
                !MainFixtureFiles.exists(fixture.destination("modules").url)
            )
        }
    }
}

extension Institute.Checkout.Test {
    /// One temporary source repository plus a family of destination paths,
    /// removed together.
    struct Fixture {
        let baseName: Swift.String
        let base: Swift.String
        let source: Swift.String
        let client: Git.Client

        init() throws {
            baseName = MainFixtureFiles.uniqueName()
            base = MainFixtureFiles.temporaryPath(baseName)
            source = MainFixtureFiles.join(base, "source")
            client = .init()
            try MainFixtureFiles.createDirectory(source)
            try client.initialize(at: source, bare: false)
            try command(["config", "user.email", "workspace@swift.institute"])
            try command(["config", "user.name", "Institute Tests"])
            try command(["branch", "-M", "main"])
        }

        func remove() {
            // swift-linter:disable:next try optional
            // REASON: Foundation.FileManager.removeItem(at:) is an untyped cross-module throwing API.
            try? MainFixtureFiles.remove(base)
        }

        func destination(_ name: Swift.String) -> File.Directory {
            .init(File.Path("\(base)/destinations/\(name)"))
        }

        func write(_ name: Swift.String, contents: Swift.String) throws {
            try MainFixtureFiles.write(contents, toURLPath: MainFixtureFiles.join(source, name))
        }

        func command(_ arguments: [Swift.String]) throws {
            try MainFixtureFiles.gitRequiringSuccess(arguments, inTemporary: baseName, child: "source")
        }

        func commit(
            _ message: Swift.String,
            contents: Swift.String
        ) throws -> Git.Object.ID {
            try write("Fixture.txt", contents: contents)
            try command(["add", "Fixture.txt"])
            try command(["commit", "-m", message])
            return try client.head(at: source)
        }
    }
}

extension File.Directory {
    fileprivate var url: Swift.String {
        MainFixtureFiles.directoryPath(description)
    }
}
