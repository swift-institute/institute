public import Byte
public import FIPS_180_4
public import Institute_Model

extension Institute.Planner {
    /// The `ci-binaries` release as the contract reads it: the names of
    /// its assets and the bytes of one asset. These two closures are the
    /// network boundary; tests bind them to an in-memory fixture release.
    public struct Release: Sendable {
        public typealias Names = @Sendable () throws(Institute.Planner.Error) -> [Swift.String]
        public typealias Fetch = @Sendable (Swift.String) throws(Institute.Planner.Error) -> [Byte]

        public let names: Names
        public let fetch: Fetch

        public init(names: @escaping Names, fetch: @escaping Fetch) {
            self.names = names
            self.fetch = fetch
        }
    }
}

extension Institute.Planner.Release {
    /// The publication made by run `run`: its one PIN asset and the
    /// SHA256SUMS asset of the same revision and run.
    public func publication(
        run: Swift.String
    ) throws(Institute.Planner.Error) -> Institute.Planner.Publication {
        guard Institute.Planner.isRun(run) else {
            throw .malformed(line: run, reason: "a publish run is a decimal run id")
        }
        let names = try names()
        let revisions = names.compactMap(Institute.Planner.Asset.init(publication:)).compactMap {
            asset -> Institute.Planner.Revision? in
            guard case .pin(let revision, run) = asset else { return nil }
            return revision
        }
        guard let revision = revisions.first else {
            throw .missing("PIN asset for publish run \(run)")
        }
        guard revisions.count == 1 else {
            throw .ambiguous("PIN assets for publish run \(run)")
        }
        return try publication(revision: revision, run: run, names: Swift.Set(names))
    }

    /// The publication whose PIN asset carries `row` verbatim.
    public func publication(
        carrying row: Institute.Planner.Row
    ) throws(Institute.Planner.Error) -> Institute.Planner.Publication {
        let names = try names()
        for asset in names.compactMap(Institute.Planner.Asset.init(publication:)) {
            guard case .pin(row.revision, let run) = asset else { continue }
            if try lines(asset.name).contains(row.line) {
                return try publication(revision: row.revision, run: run, names: Swift.Set(names))
            }
        }
        throw .unpublished(row.line)
    }

    /// Every line of every PIN asset published for `revision`.
    public func published(
        revision: Institute.Planner.Revision
    ) throws(Institute.Planner.Error) -> Swift.Set<Swift.String> {
        var published: Swift.Set<Swift.String> = []
        for asset in try names().compactMap(Institute.Planner.Asset.init(publication:)) {
            guard case .pin(revision, _) = asset else { continue }
            published.formUnion(try lines(asset.name))
        }
        return published
    }

    /// Every published PIN row for `platform`, with each publication's
    /// revision, platform cardinality and checksum record validated.
    public func published(
        _ platform: Institute.Planner.Platform
    ) throws(Institute.Planner.Error) -> [Institute.Planner.Publication] {
        let names = try names()
        let available = Swift.Set(names)
        var publications: [Institute.Planner.Publication] = []
        for asset in names.compactMap(Institute.Planner.Asset.init(publication:)) {
            guard case .pin(let revision, let run) = asset else { continue }
            let publication = try publication(revision: revision, run: run, names: available)
            _ = publication.row(for: platform)
            publications.append(publication)
        }
        return publications
    }

    /// The bytes of the asset named `name`, refused unless they hash to
    /// `digest`.
    public func verified(
        _ name: Swift.String,
        digest: FIPS_180_4.Digest
    ) throws(Institute.Planner.Error) -> [Byte] {
        let bytes = try fetch(name)
        let actual = Institute.Planner.digest(of: bytes)
        guard actual == digest else {
            throw .mismatch(asset: name, expected: digest.hex, actual: actual.hex)
        }
        return bytes
    }

    /// The planner `publication` published for `platform`: its binary,
    /// graph and toolchain record, each verified against both the PIN row
    /// and the run's SHA256SUMS.
    public func executable(
        _ platform: Institute.Planner.Platform,
        of publication: Institute.Planner.Publication
    ) throws(Institute.Planner.Error) -> Institute.Planner.Executable {
        let row = publication.row(for: platform)
        let binary = try verified(
            .binary(platform, row.binary),
            digest: row.binary,
            in: publication
        )
        _ = try verified(
            .graph(platform, row.graph),
            digest: row.graph,
            in: publication
        )
        let toolchain = Institute.Planner.Asset.toolchain(platform, row.binary).name
        guard let recorded = publication.checksums[toolchain] else {
            throw .missing("checksum for \(toolchain)")
        }
        return .init(
            row: row,
            binary: binary,
            toolchain: Swift.String(
                decoding: try verified(toolchain, digest: recorded),
                as: Swift.UTF8.self
            )
        )
    }

    private func verified(
        _ asset: Institute.Planner.Asset,
        digest: FIPS_180_4.Digest,
        in publication: Institute.Planner.Publication
    ) throws(Institute.Planner.Error) -> [Byte] {
        guard let recorded = publication.checksums[asset.name] else {
            throw .missing("checksum for \(asset.name)")
        }
        guard recorded == digest else {
            throw .mismatch(asset: asset.name, expected: digest.hex, actual: recorded.hex)
        }
        return try verified(asset.name, digest: digest)
    }

    private func publication(
        revision: Institute.Planner.Revision,
        run: Swift.String,
        names: Swift.Set<Swift.String>
    ) throws(Institute.Planner.Error) -> Institute.Planner.Publication {
        let sums = Institute.Planner.Asset.sums(revision, run: run)
        guard names.contains(sums.name) else { throw .missing(sums.name) }
        let sumsText = try text(sums.name)
        let checksums = try Institute.Planner.Checksum.checksums(in: sumsText)
        let ancestry = Institute.Planner.Asset.ancestry(revision, run: run)
        let ancestryText: Swift.String?
        if names.contains(ancestry.name) {
            guard let digest = checksums[ancestry.name] else {
                throw .missing("checksum for \(ancestry.name)")
            }
            ancestryText = Swift.String(
                decoding: try verified(ancestry.name, digest: digest),
                as: Swift.UTF8.self
            )
        } else {
            ancestryText = nil
        }
        return try .init(
            revision: revision,
            run: run,
            pin: text(Institute.Planner.Asset.pin(revision, run: run).name),
            sums: sumsText,
            ancestry: ancestryText
        )
    }

    private func text(_ name: Swift.String) throws(Institute.Planner.Error) -> Swift.String {
        Swift.String(decoding: try fetch(name), as: Swift.UTF8.self)
    }

    private func lines(_ name: Swift.String) throws(Institute.Planner.Error) -> [Swift.String] {
        try text(name).split(separator: "\n").map(Swift.String.init)
    }
}
