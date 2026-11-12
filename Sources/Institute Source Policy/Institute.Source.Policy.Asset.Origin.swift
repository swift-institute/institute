public import Institute_Model
public import Source_Profile

extension Institute.Source.Policy.Asset {
    public enum Origin: Sendable {
        case release(base: Swift.String)
        case releaseArchive(
            base: Swift.String,
            archive: Swift.String,
            digest: Source_Profile::Source.Profile.Digest,
            member: Swift.String
        )
        case xcode(
            application: Swift.String,
            version: Swift.String,
            relativePath: Swift.String
        )
        /// A tool of the Swift toolchain installed on the machine, found on
        /// `PATH` and run where it is: it loads the toolchain's runtime
        /// libraries from beside itself, so it cannot be copied out.
        /// `release` and `distribution` name the swift.org download the
        /// pinned digest was taken from.
        case toolchain(
            release: Swift.String,
            distribution: Swift.String,
            executable: Swift.String
        )
    }
}
