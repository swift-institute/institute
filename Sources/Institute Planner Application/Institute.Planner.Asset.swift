public import FIPS_180_4
public import Institute_Model

extension Institute.Planner {
    /// A `ci-binaries` asset, named by what it carries. Binaries, graphs
    /// and toolchain records are named by their own digest (the toolchain
    /// record by its binary's); PIN and SHA256SUMS assets by the revision
    /// and the publishing run.
    public enum Asset: Hashable, Sendable {
        case binary(Platform, FIPS_180_4.Digest)
        case graph(Platform, FIPS_180_4.Digest)
        case toolchain(Platform, FIPS_180_4.Digest)
        case pin(Revision, run: Swift.String)
        case sums(Revision, run: Swift.String)
    }
}

extension Institute.Planner.Asset {
    public var name: Swift.String {
        switch self {
        case .binary(let platform, let digest): "institute-\(platform.rawValue)-\(digest.hex)"
        case .graph(let platform, let digest): "Package.resolved-\(platform.rawValue)-\(digest.hex)"
        case .toolchain(let platform, let digest):
            "TOOLCHAIN-\(platform.rawValue)-\(digest.hex).txt"
        case .pin(let revision, let run): "PIN-\(revision)-\(run)"
        case .sums(let revision, let run): "SHA256SUMS-\(revision)-\(run)"
        }
    }

    /// Reads a PIN or SHA256SUMS asset name; `nil` for any other name.
    public init?(publication name: Swift.String) {
        let fields = name.split(separator: "-", omittingEmptySubsequences: false)
        guard fields.count == 3, Institute.Planner.isRun(fields[2]) else { return nil }
        let revision: Institute.Planner.Revision
        do throws(Institute.Planner.Error) {
            revision = try .init(fields[1])
        } catch {
            return nil
        }
        switch fields[0] {
        case "PIN": self = .pin(revision, run: Swift.String(fields[2]))
        case "SHA256SUMS": self = .sums(revision, run: Swift.String(fields[2]))
        default: return nil
        }
    }
}

extension Institute.Planner {
    /// Whether `text` is a GitHub Actions run id: one or more decimal digits.
    static func isRun(_ text: some StringProtocol) -> Swift.Bool {
        !text.isEmpty && text.utf8.allSatisfy { (48...57).contains($0) }
    }
}
