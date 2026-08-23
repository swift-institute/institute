public import Institute_Model
public import Source_Profile

extension Institute.Source.Policy.Asset {
    public enum Origin: Sendable {
        case release(base: Swift.String)
        case releaseArchive(
            base: Swift.String,
            archive: Swift.String,
            digest: Source_Profile.Source.Profile.Digest,
            member: Swift.String
        )
        case xcode(
            application: Swift.String,
            version: Swift.String,
            build: Swift.String,
            relativePath: Swift.String
        )
    }
}
