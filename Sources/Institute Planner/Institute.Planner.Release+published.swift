import Byte
import Foundation
public import Institute_Model

extension Institute.Planner.Release {
    /// The live `ci-binaries` release of swift-institute/institute, read from
    /// GitHub's public endpoints without any credential: the release's public
    /// expanded-assets page, and each asset through its download address.
    public static var published: Self {
        let repository = Institute.Planner.publisher
        let tag = Institute.Planner.tag
        return .init(
            names: { () throws(Institute.Planner.Error) in
                let bytes = try Institute.Planner.Curl.get(
                    "https://github.com/\(repository)/releases/expanded_assets/\(tag)"
                )
                return try assets(
                    listing: Swift.String(decoding: bytes, as: Swift.UTF8.self),
                    tag: tag
                )
            },
            fetch: { name throws(Institute.Planner.Error) in
                guard !name.isEmpty, !name.contains(where: { $0 == "/" || $0 == "?" || $0 == "#" })
                else {
                    throw .malformed(line: name, reason: "an asset name is one path component")
                }
                return try Institute.Planner.Curl.get(
                    "https://github.com/\(repository)/releases/download/\(tag)/\(name)"
                )
            }
        )
    }
}

extension Institute.Planner.Release {
    /// The asset names a release's expanded-assets page links to.
    ///
    /// Links are matched on `/releases/download/<tag>/` alone, never on the
    /// repository path before it: GitHub serves a renamed repository's page
    /// under its new name, so a planner that matched the name it was built
    /// with would find no assets and refuse to run.
    static func assets(
        listing: Swift.String,
        tag: Swift.String
    ) throws(Institute.Planner.Error) -> [Swift.String] {
        let marker = "/releases/download/\(tag)/"
        let names = listing.components(separatedBy: marker).dropFirst().compactMap { tail in
            tail.split(separator: "\"", maxSplits: 1).first.map(Swift.String.init)
        }
        guard !names.isEmpty else {
            throw .malformed(line: "release \(tag)", reason: "no asset links")
        }
        return Swift.Set(names).sorted()
    }
}
