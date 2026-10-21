public import FIPS_180_4
import Institute_Development
public import Institute_Model

extension Institute.Planner {
    /// Whether the running binary is the planner the consumer pins.
    ///
    /// A binary cannot carry the revision it was built from, so it is
    /// identified by its own digest: it is current when that digest is the
    /// one the consumer's winning row names for the pinned revision on this
    /// platform. Anything else is stale, and so is a binary that cannot be
    /// compared at all.
    public enum Freshness {}
}

extension Institute.Planner.Freshness {
    /// Refuses unless `running` is the digest `consumer` pins for `platform`.
    public static func verify(
        running: FIPS_180_4.Digest,
        platform: Institute.Planner.Platform,
        consumer: Institute.Planner.Consumer
    ) throws(Institute.Planner.Error) {
        let row = try consumer.current(platform)
        guard row.binary == running else {
            throw .stale(
                running: running.hex,
                pinned: row.binary.hex,
                revision: row.revision.description,
                platform: platform.rawValue
            )
        }
    }

    /// Refuses unless this process is the planner the live consumer pins for
    /// the platform it runs on.
    public static func enforce() throws(Institute.Error) {
        guard let platform = Institute.Planner.Platform.host else {
            throw .configuration("no planner is published for this platform, so this binary cannot be verified")
        }
        let executable = try Institute.Installation.running()
        do throws(Institute.Planner.Error) {
            let bytes = try Institute.Planner.read(executable.path)
            try verify(
                running: Institute.Planner.digest(of: bytes),
                platform: platform,
                consumer: .published
            )
        } catch {
            throw .configuration("institute refuses to run: \(error)")
        }
    }
}
