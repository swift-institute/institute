import File_System
import Foundation
import Testing

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

extension Institute.Installation {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Institute.Installation.Test {
    struct Fixture {
        let base: URL
        let home: File.Directory
        let source: File
        let environmentPath: Swift.String

        init(exposesCommand: Swift.Bool = true) throws {
            base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

            let physical = File.Directory(
                try File.System.Canonical.resolve(try File.Path(base.path))
            )
            home = physical[directory: "home"]
            let sourceDirectory = physical[directory: "source"]
            source = sourceDirectory[file: "institute"]
            try home.create.recursive()
            try sourceDirectory.create.recursive()
            try source.write.atomic("coordinator-version-one")

            let commandDirectory = home[directory: ".local"][directory: "bin"]
            environmentPath =
                exposesCommand
                ? [commandDirectory.description, "/usr/bin", "/bin"]
                    .joined(separator: Self.pathSeparator)
                : ["/usr/bin", "/bin"].joined(separator: Self.pathSeparator)
        }

        /// The platform's PATH list separator, matching what
        /// `Process.Spawn.Executable.directories(in:)` splits on.
        static var pathSeparator: Swift.String {
            #if os(Windows)
                ";"
            #else
                ":"
            #endif
        }

        var installation: Institute.Installation {
            get throws {
                try Institute.Installation(
                    source: source,
                    home: home,
                    environmentPath: environmentPath
                )
            }
        }

        var command: File {
            home[directory: ".local"][directory: "bin"][file: "institute"]
        }

        var root: File.Directory {
            let share = home[directory: ".local"][directory: "share"]
            let institute = share[directory: "swift-institute"]
            return institute[directory: "institute"]
        }

        func remove() {
            try? FileManager.default.removeItem(at: base)
        }

        func contents(of file: File) throws -> Swift.String {
            try Swift.String(contentsOfFile: file.description, encoding: .utf8)
        }
    }
}

extension Institute.Installation.Test.Unit {
    /// The positive control: a clean account root gains a command whose bytes
    /// live outside SwiftPM's generated build directory.
    @Test
    func `install exposes a durable executable through the account command directory`() throws {
        let fixture = try Institute.Installation.Test.Fixture()
        defer { fixture.remove() }
        let installation = try fixture.installation

        try installation.install()

        #expect(
            try fixture.contents(of: installation.executable)
                == "coordinator-version-one"
        )
        #expect(
            try File.System.Metadata.Permissions(at: installation.executable.path)
                == .executable
        )
        #expect(
            try File.System.Canonical.resolve(installation.command.path)
                == installation.executable.path
        )
    }

    @Test
    func `install refreshes an installation carrying its receipt`() throws {
        let fixture = try Institute.Installation.Test.Fixture()
        defer { fixture.remove() }
        let installation = try fixture.installation
        try installation.install()
        try fixture.source.write.atomic("coordinator-version-two")

        try installation.install()

        #expect(
            try fixture.contents(of: installation.executable)
                == "coordinator-version-two"
        )
        #expect(
            try File.System.Canonical.resolve(installation.command.path)
                == File.System.Canonical.resolve(installation.executable.path)
        )
    }

    @Test
    func `install verifies paths beneath a symbolic ancestor`() throws {
        let fixture = try Institute.Installation.Test.Fixture()
        defer { fixture.remove() }
        let alias = fixture.base.appending(path: "alias")
        try FileManager.default.createSymbolicLink(
            at: alias,
            withDestinationURL: fixture.base
        )
        let home = File.Directory(try File.Path(alias.appending(path: "home").path))
        let commandDirectory = home[directory: ".local"][directory: "bin"]
        let installation = try Institute.Installation(
            source: fixture.source,
            home: home,
            environmentPath: [commandDirectory.description, "/usr/bin", "/bin"]
                .joined(separator: Institute.Installation.Test.Fixture.pathSeparator)
        )

        try installation.install()

        #expect(
            try File.System.Canonical.resolve(installation.command.path)
                == File.System.Canonical.resolve(installation.executable.path)
        )
    }
}

extension Institute.Installation.Test.`Edge Case` {
    @Test
    func `install refuses an unmanaged executable before creating managed state`() throws {
        let fixture = try Institute.Installation.Test.Fixture()
        defer { fixture.remove() }
        let commandDirectory = fixture.home[directory: ".local"][directory: "bin"]
        try commandDirectory.create.recursive()
        try fixture.command.write.atomic("user-command")
        let installation = try fixture.installation

        #expect(throws: Institute.Error.self) {
            try installation.install()
        }
        #expect(try fixture.contents(of: fixture.command) == "user-command")
        #expect(!fixture.root.stat.exists)
    }

    @Test
    func `install refuses an unmanaged symbolic link before creating managed state`() throws {
        let fixture = try Institute.Installation.Test.Fixture()
        defer { fixture.remove() }
        let foreignDirectory = fixture.home[directory: "elsewhere"]
        let foreign = foreignDirectory[file: "institute"]
        try foreignDirectory.create.recursive()
        try foreign.write.atomic("foreign-command")
        let commandDirectory = fixture.home[directory: ".local"][directory: "bin"]
        try commandDirectory.create.recursive()
        try FileManager.default.createSymbolicLink(
            atPath: fixture.command.description,
            withDestinationPath: foreign.description
        )
        let installation = try fixture.installation

        #expect(throws: Institute.Error.self) {
            try installation.install()
        }
        #expect(
            try File.System.Canonical.resolve(fixture.command.path)
                == File.System.Canonical.resolve(foreign.path)
        )
        #expect(!fixture.root.stat.exists)
    }

    @Test
    func `install refuses to adopt an unreceipted installation directory`() throws {
        let fixture = try Institute.Installation.Test.Fixture()
        defer { fixture.remove() }
        try fixture.root.create.recursive()
        try fixture.root[file: "local-state"].write.atomic("mine")
        let installation = try fixture.installation

        #expect(throws: Institute.Error.self) {
            try installation.install()
        }
        #expect(fixture.root[file: "local-state"].stat.isFile)
        #expect(!fixture.command.stat.exists)
    }

    @Test
    func `install refuses a command directory that the shell cannot discover`() throws {
        let fixture = try Institute.Installation.Test.Fixture(exposesCommand: false)
        defer { fixture.remove() }
        let installation = try fixture.installation

        #expect(throws: Institute.Error.self) {
            try installation.install()
        }
        #expect(!fixture.root.stat.exists)
        #expect(!fixture.command.stat.exists)
    }
}
