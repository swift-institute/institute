public import FIPS_180_4
public import Institute_Model

extension Institute.Planner {
    /// One `publish-planner` run's record: the PIN asset's rows, exactly
    /// one per platform and all for the run's revision, and the
    /// SHA256SUMS asset's checksums.
    public struct Publication: Sendable {
        public let revision: Revision
        public let run: Swift.String
        /// The PIN asset's rows in published order.
        public let rows: [Row]
        public let checksums: [Swift.String: FIPS_180_4.Digest]
        public let ancestors: Swift.Set<Revision>?
        let linux: Row
        let macos: Row

        public init(
            revision: Revision,
            run: Swift.String,
            pin: Swift.String,
            sums: Swift.String,
            ancestry: Swift.String? = nil
        ) throws(Institute.Planner.Error) {
            let rows = try Row.rows(in: pin)
            for row in rows where row.revision != revision {
                throw .malformed(
                    line: row.line,
                    reason: "PIN-\(revision)-\(run) carries a row for another revision"
                )
            }
            func only(_ platform: Platform) throws(Institute.Planner.Error) -> Row {
                let matching = rows.filter { $0.platform == platform }
                guard let row = matching.first else {
                    throw .absent(revision: revision.description, platform: platform.rawValue)
                }
                guard matching.count == 1 else {
                    throw .ambiguous("\(platform.rawValue) rows in PIN-\(revision)-\(run)")
                }
                return row
            }
            self.revision = revision
            self.run = run
            self.rows = rows
            self.checksums = try Checksum.checksums(in: sums)
            if let ancestry {
                let ancestors = try Swift.Set(
                    ancestry.split(separator: "\n").map(Revision.init)
                )
                guard ancestors.contains(revision) else {
                    throw .malformed(
                        line: "ANCESTORS-\(revision)-\(run)",
                        reason: "does not contain its published revision"
                    )
                }
                self.ancestors = ancestors
            } else {
                self.ancestors = nil
            }
            self.linux = try only(.linux)
            self.macos = try only(.macos)
        }
    }
}

extension Institute.Planner.Publication {
    /// The publication's row for `platform`; one exists by construction.
    public func row(for platform: Institute.Planner.Platform) -> Institute.Planner.Row {
        switch platform {
        case .linux: linux
        case .macos: macos
        }
    }
}
