public import FIPS_180_4
public import File_System
import Institute_Installation
public import Institute_Model

extension Institute.Planner {
    /// Whether the running binary is a published planner at or after the
    /// revision the consumer pins.
    ///
    /// A binary cannot carry the revision it was built from, so it is
    /// identified by its own digest. It is current when a published PIN row
    /// for this platform names that digest and its source revision is the
    /// pinned revision or a descendant of it on the publisher's main branch,
    /// as recorded by that publication's checksummed ancestry asset.
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
        release: Institute.Planner.Release
    ) throws(Institute.Planner.Error) {
        let pinned = try consumer.current(platform)
        for publication in try release.published(platform) {
            let row = publication.row(for: platform)
            guard row.binary == running else { continue }
            if row.revision == pinned.revision { return }
            if publication.ancestors?.contains(pinned.revision) == true { return }
        }
        throw .stale(
            running: running.hex,
            revision: pinned.revision.description,
            platform: platform.rawValue
        )
    }

    /// Whether a binary should be replaced by the pinned planner rather than
    /// run: `false` when it is current, `true` when it is stale and is the
    /// account's own installation. A stale binary that isn't, such as a
    /// development build, is refused, because replacing it would silently run
    /// other code than was asked for; so is any failure to compare it.
    static func replaced(
        running: FIPS_180_4.Digest,
        platform: Institute.Planner.Platform,
        consumer: Institute.Planner.Consumer,
        release: Institute.Planner.Release,
        installed: Swift.Bool
    ) throws(Institute.Planner.Error) -> Swift.Bool {
        do throws(Institute.Planner.Error) {
            try verify(running: running, platform: platform, consumer: consumer, release: release)
            return false
        } catch {
            guard case .stale = error, installed else { throw error }
            return true
        }
    }

    /// Makes sure the live consumer's pinned planner is what runs: refuses a
    /// binary that may not run, and when this process is the account's own
    /// installation and behind its pin, installs the pinned planner, verifies
    /// it and returns it, for the caller to run instead of carrying on.
    /// Returns `nil` when this process is current.
    public static func refresh() throws(Institute.Error) -> File? {
        guard let platform = Institute.Planner.Platform.host else {
            throw .configuration(
                "no planner is published for this platform, so this binary cannot be verified"
            )
        }
        let running = try Institute.Installation.running()
        let pinned: Institute.Planner.Executable
        do throws(Institute.Planner.Error) {
            let behind = try replaced(
                running: Institute.Planner.digest(of: Institute.Planner.read(running.path)),
                platform: platform,
                consumer: .published,
                release: .published,
                installed: platform == .macos && Institute.Installation.managed(running)
            )
            guard behind else { return nil }
            pinned = try Institute.Planner.Pinned.executable(
                consumer: .published,
                release: .published,
                platform: platform
            )
        } catch {
            throw .configuration("institute refuses to run: \(error)")
        }
        let installation = try pinned.install()
        do throws(Institute.Planner.Error) {
            try verify(
                running: Institute.Planner.digest(of: Institute.Planner.read(installation.executable.path)),
                platform: platform,
                consumer: .published,
                release: .published
            )
        } catch {
            throw .configuration("the planner institute installed does not verify: \(error)")
        }
        return installation.executable
    }
}
