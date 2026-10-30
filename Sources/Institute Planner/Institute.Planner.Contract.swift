public import Institute_Model

extension Institute.Planner {
    /// The adoption contract `verify-planner-pins.sh` states, over the
    /// consumer's two files and the release. It refuses when:
    ///
    /// - the pin is not exactly one 40-hex line;
    /// - a planner row is malformed or names an unknown platform;
    /// - the pinned revision has no row for a platform;
    /// - a winning row for the pinned revision is not carried verbatim by
    ///   any `PIN-<revision>-<run>` asset — a row typed by hand;
    /// - the binary or graph a winning row names is missing from the
    ///   release or does not hash to the row's digest.
    public enum Contract {}
}

extension Institute.Planner.Contract {
    /// Verifies `pin` and `ledger` against `release`, returning the winning
    /// row per platform.
    public static func verify(
        pin: Institute.Planner.Pin,
        ledger: Institute.Planner.Ledger,
        release: Institute.Planner.Release
    ) throws(Institute.Planner.Error) -> [Institute.Planner.Row] {
        let published = try release.published(revision: pin.revision)
        var winners: [Institute.Planner.Row] = []
        for platform in Institute.Planner.Platform.allCases {
            guard let row = ledger.winner(pin.revision, platform) else {
                throw .absent(revision: pin.revision.description, platform: platform.rawValue)
            }
            guard published.contains(row.line) else {
                throw .unpublished(row.line)
            }
            _ = try release.verified(
                Institute.Planner.Asset.binary(platform, row.binary).name,
                digest: row.binary
            )
            _ = try release.verified(
                Institute.Planner.Asset.graph(platform, row.graph).name,
                digest: row.graph
            )
            winners.append(row)
        }
        return winners
    }
}
