public import FIPS_180_4
import File_System
import Institute_Development
public import Institute_Model

extension Institute.Planner {
    /// Whether the running binary is a published planner at or after the
    /// revision the consumer pins.
    ///
    /// A binary cannot carry the revision it was built from, so it is
    /// identified by its own digest. It is current when a published PIN row
    /// for this platform names that digest and its source revision is the
    /// pinned revision or a descendant of it on the publisher's main branch.
    /// Anything else is stale, and so is a binary that cannot be compared.
    public enum Freshness {}
}

extension Institute.Planner.Freshness {
    /// Refuses unless `running` is published for `platform` at or after the
    /// revision `consumer` pins.
    public static func verify(
        running: FIPS_180_4.Digest,
        platform: Institute.Planner.Platform,
        consumer: Institute.Planner.Consumer,
        release: Institute.Planner.Release,
        history: Institute.Planner.History
    ) throws(Institute.Planner.Error) {
        let pinned = try consumer.current(platform)
        for row in try release.published(platform) where row.binary == running {
            if try history.contains(row.revision, atOrAfter: pinned.revision) { return }
        }
        throw .stale(
            running: running.hex,
            revision: pinned.revision.description,
            platform: platform.rawValue
        )
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
                consumer: .published,
                release: .published,
                history: .published
            )
        } catch {
            throw .configuration("institute refuses to run: \(error)")
        }
    }
}
