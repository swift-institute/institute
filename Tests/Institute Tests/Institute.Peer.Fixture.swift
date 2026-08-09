import File_System
import Foundation
import Git_Foundation

@testable import Institute_Model
@testable import Institute_Inventory
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Lint
@testable import Institute_Pages
@testable import Institute_Doctor
@testable import Institute_Conversion
@testable import Institute_Instruments

extension Institute.Peer {
    /// A disposable entry root holding one Institute hierarchy and any
    /// peer roots a test materializes beside it.
    ///
    /// ``Institute/Doctor/Fixture`` places its hierarchy directly in the
    /// system temporary directory, which makes the *entry* root — the
    /// hierarchy's parent — shared machine state. Peer resolution reads
    /// the entry root, so peer tests need this fixture's extra level: the
    /// entry is a private `tmp/<uuid>` directory, the hierarchy sits at
    /// `institute/` inside it, and peer roots materialize beside the
    /// hierarchy exactly as they do in production.
    struct Fixture {
        /// The private entry root, `tmp/<uuid>`.
        let base: URL
        let root: Institute.Root

        init() throws {
            base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            let checkout =
                base
                .appending(path: "institute")
                .appending(path: "Institute")
            try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
            root = try Institute.Root(
                checkout: File.Directory(validating: checkout.path)
            )
        }
    }
}

extension Institute.Peer.Fixture {
    /// Creates the peer's root directory beside the hierarchy.
    func materializeRoot(of peer: Institute.Peer) throws {
        try FileManager.default.createDirectory(
            at: base.appending(path: peer.name),
            withIntermediateDirectories: true
        )
    }

    /// Writes `contents` at `relative` under the peer's root, creating
    /// intermediate directories.
    func write(_ contents: Swift.String, at relative: Swift.String, for peer: Institute.Peer) throws {
        let destination = base.appending(path: peer.name).appending(path: relative)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: destination, atomically: true, encoding: .utf8)
    }

    /// Materializes `repository` at its peer-layout location as a real
    /// Git repository. The location is derived through
    /// ``Institute/Peer/Layout`` — the fixture holds no layout assumption
    /// of its own.
    func materialize(
        _ repository: Institute.Peer.Repository,
        in peer: Institute.Peer
    ) throws {
        let location = try Institute.Peer.Layout.directory(
            for: repository,
            in: peer.name,
            at: File.Directory(validating: base.appending(path: peer.name).path)
        )
        try FileManager.default.createDirectory(
            atPath: location.description,
            withIntermediateDirectories: true
        )
        try Git.Client().initialize(at: location.description, bare: false)
    }

    /// A doctor over an empty selection whose toolchain interrogation is
    /// hermetic, measuring exactly the given peers.
    func doctor(peers: [Institute.Peer]) -> Institute.Doctor {
        .init(
            root: root,
            configuration: .init(
                version: 1,
                scope: "test",
                swift: "6.3",
                xcode: "26.0",
                repositories: []
            ),
            selection: .init(repositories: [], origin: .committed(count: 0)),
            peers: peers,
            environment: { _ in nil },
            tool: Institute.Doctor.Fixture.interrogation
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: base)
    }
}
