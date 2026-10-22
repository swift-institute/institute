public import Institute_Model

extension Institute.Planner.Release {
    /// The live `ci-binaries` release of institute-application, read from
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
                let listing = Swift.String(decoding: bytes, as: Swift.UTF8.self)
                let marker = "/\(repository)/releases/download/\(tag)/"
                let names = listing.components(separatedBy: marker).dropFirst().compactMap { tail in
                    tail.split(separator: "\"", maxSplits: 1).first.map(Swift.String.init)
                }
                guard !names.isEmpty else {
                    throw .malformed(line: "release \(tag)", reason: "no asset links")
                }
                return Swift.Set(names).sorted()
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
