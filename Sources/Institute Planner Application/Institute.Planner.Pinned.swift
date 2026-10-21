public import Institute_Model

extension Institute.Planner {
    /// The planner the consumer pins: the winning row for the pinned
    /// revision, resolved against the release and verified.
    public enum Pinned {}
}

extension Institute.Planner.Pinned {
    /// The published planner `consumer` pins for `platform`.
    ///
    /// Fails closed: the row must be carried verbatim by a published PIN
    /// asset, and the binary, graph and toolchain record must each hash to
    /// the digest the row and the run's checksums name.
    public static func executable(
        consumer: Institute.Planner.Consumer,
        release: Institute.Planner.Release,
        platform: Institute.Planner.Platform
    ) throws(Institute.Planner.Error) -> Institute.Planner.Executable {
        let row = try consumer.current(platform)
        let publication = try release.publication(carrying: row)
        let executable = try release.executable(platform, of: publication)
        guard executable.row.line == row.line else {
            throw .unpublished(row.line)
        }
        return executable
    }
}
