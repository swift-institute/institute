import File_System
import Institute_Model
import Institute_Source_Policy
import Source_Profile
import Testing

@testable import Institute_Source

/// A toolchain laid out as swift.org's is, `usr/bin/<tool>`, in a fresh
/// temporary directory, with `/usr/local/bin`-style links to its tools
/// in a second directory.
private struct Toolchain {
    let root: Swift.String
    let bin: Swift.String
    let links: Swift.String

    init(tool: Swift.String, contents: Swift.String) {
        root = MainFixtureFiles.resolvedTemporaryPath("toolchain-\(MainFixtureFiles.uniqueName())")
        bin = MainFixtureFiles.join(root, "usr/bin")
        links = MainFixtureFiles.join(root, "links")
        #expect(MainFixtureFiles.makeDirectory(bin))
        #expect(MainFixtureFiles.makeDirectory(links))
        #expect(MainFixtureFiles.createFile(MainFixtureFiles.join(bin, tool), contents: Swift.Array(contents.utf8)))
        #expect(MainFixtureFiles.link(MainFixtureFiles.join(links, tool), to: MainFixtureFiles.join(bin, tool)))
    }

    func remove() { MainFixtureFiles.discard(root) }
}

private let standIn = Source.Engine.Process { _, _, _, _ in
    .init(status: 127, output: "", diagnostics: "no process is expected")
}

private func asset(
    digest: Source.Profile.Digest
) -> Institute.Source.Policy.Asset {
    .init(
        name: "swift-format",
        digest: digest,
        origin: .toolchain(
            release: "swift-6.4.2-RELEASE",
            distribution: "ubuntu24.04",
            executable: "swift-format"
        )
    )
}

@Test
func `the pinned toolchain tool is taken where it is, through its links, when its digest matches`() async throws {
    let toolchain = Toolchain(tool: "swift-format", contents: "pinned")
    let tool = MainFixtureFiles.join(toolchain.bin, "swift-format")
    let digest = try Institute.Source.Application.digest(file: tool)
    let tools = try File.Directory(validating: MainFixtureFiles.join(toolchain.root, "tools"))

    let acquired = try await Institute.Source.Acquisition(
        process: standIn,
        search: ["relative/ignored", MainFixtureFiles.join(toolchain.root, "absent"), toolchain.links]
    ).acquire(asset(digest: digest), executable: true, into: tools)

    #expect(MainFixtureFiles.resolvingSymlinks(acquired.description) == MainFixtureFiles.resolvingSymlinks(tool))
    #expect(MainFixtureFiles.lastComponent(of: MainFixtureFiles.parent(of: acquired.description)) == "bin")
    #expect(!MainFixtureFiles.exists(tools.description))
    toolchain.remove()
}

@Test
func `a toolchain tool with another digest is refused, naming what is pinned`() async throws {
    let toolchain = Toolchain(tool: "swift-format", contents: "another build")
    let actual = try Institute.Source.Application.digest(
        file: MainFixtureFiles.join(toolchain.bin, "swift-format")
    )
    let pinned = Source.Profile.Digest(Swift.String(repeating: "a", count: 64))
    let tools = try File.Directory(validating: MainFixtureFiles.join(toolchain.root, "tools"))

    let error = await #expect(throws: Institute.Error.self) {
        _ = try await Institute.Source.Acquisition(process: standIn, search: [toolchain.links])
            .acquire(asset(digest: pinned), executable: true, into: tools)
    }

    let message = error?.description ?? ""
    #expect(message.contains(actual.hex))
    #expect(message.contains(pinned.hex))
    #expect(message.contains("swift-6.4.2-RELEASE"))
    #expect(message.contains("ubuntu24.04"))
    toolchain.remove()
}

@Test
func `the first tool on the search path decides, as it would for the shell`() async throws {
    let first = Toolchain(tool: "swift-format", contents: "first on the path")
    let second = Toolchain(tool: "swift-format", contents: "pinned")
    let digest = try Institute.Source.Application.digest(
        file: MainFixtureFiles.join(second.bin, "swift-format")
    )
    let tools = try File.Directory(validating: MainFixtureFiles.join(first.root, "tools"))

    await #expect(throws: Institute.Error.self) {
        _ = try await Institute.Source.Acquisition(process: standIn, search: [first.bin, second.bin])
            .acquire(asset(digest: digest), executable: true, into: tools)
    }
    let acquired = try await Institute.Source.Acquisition(process: standIn, search: [second.bin, first.bin])
        .acquire(asset(digest: digest), executable: true, into: tools)
    #expect(
        MainFixtureFiles.resolvingSymlinks(acquired.description)
            == MainFixtureFiles.resolvingSymlinks(MainFixtureFiles.join(second.bin, "swift-format"))
    )
    first.remove()
    second.remove()
}

@Test
func `a search path without the tool is refused`() async throws {
    let toolchain = Toolchain(tool: "swift-build", contents: "not the tool")
    let tools = try File.Directory(validating: MainFixtureFiles.join(toolchain.root, "tools"))

    let error = await #expect(throws: Institute.Error.self) {
        _ = try await Institute.Source.Acquisition(process: standIn, search: [toolchain.bin])
            .acquire(
                asset(digest: .init(Swift.String(repeating: "a", count: 64))),
                executable: true,
                into: tools
            )
    }

    #expect(error?.description.hasPrefix("no swift-format on PATH") == true)
    toolchain.remove()
}

@Test
func `an Xcode application is refused for a toolchain tool`() async throws {
    let toolchain = Toolchain(tool: "swift-format", contents: "pinned")
    let digest = try Institute.Source.Application.digest(
        file: MainFixtureFiles.join(toolchain.bin, "swift-format")
    )
    let tools = try File.Directory(validating: MainFixtureFiles.join(toolchain.root, "tools"))

    await #expect(throws: Institute.Error.self) {
        _ = try await Institute.Source.Acquisition(process: standIn, search: [toolchain.bin])
            .acquire(
                asset(digest: digest),
                executable: true,
                xcodeApplication: "/Applications/Xcode_27.2.app",
                into: tools
            )
    }
    toolchain.remove()
}

@Test
func `the Linux linter runner is given the runtime of the toolchain swift-format is in`() {
    typealias Application = Institute.Source.Application
    #expect(
        Application.runtime(swiftFormat: "/opt/swift/usr/bin/swift-format", on: .linuxX86_64)
            == ["LD_LIBRARY_PATH": "/opt/swift/usr/lib/swift/linux"]
    )
    #expect(Application.runtime(swiftFormat: "/tools/swift-format", on: .linuxX86_64).isEmpty)
    #expect(
        Application.runtime(
            swiftFormat: "/package/.source/tools/swift-format",
            on: .macOSARM64
        ).isEmpty
    )
    #expect(Application.runtime(swiftFormat: "/opt/swift/usr/bin/swift-format", on: nil).isEmpty)
}

@Test
func `an archive member is extracted by the platform's own tool`() {
    let command = Institute.Source.Acquisition.unarchive(
        "/work/archive.zip",
        member: "swiftlint",
        into: "/work/contents"
    )
    #if os(macOS)
        #expect(command.executable == "/usr/bin/ditto")
        #expect(command.arguments == ["-x", "-k", "/work/archive.zip", "/work/contents"])
    #else
        #expect(command.executable == "/usr/bin/unzip")
        #expect(command.arguments == ["-q", "-o", "/work/archive.zip", "swiftlint", "-d", "/work/contents"])
    #endif
}
