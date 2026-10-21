public import Institute_Model
import JSON

extension Institute.Planner.Release {
    /// The live `ci-binaries` release of institute-application, read from
    /// GitHub's public endpoints without any credential: the release listing
    /// through the REST API, each asset through its download address.
    public static var published: Self {
        let repository = Institute.Planner.publisher
        let tag = Institute.Planner.tag
        return .init(
            names: { () throws(Institute.Planner.Error) in
                let listing = try Institute.Planner.Curl.get(
                    "https://api.github.com/repos/\(repository)/releases/tags/\(tag)"
                )
                let release: JSON
                do throws(JSON.Error) {
                    release = try JSON.parse(listing)
                } catch {
                    throw .malformed(line: "release \(tag)", reason: "not JSON: \(error)")
                }
                guard let assets = (release["assets"] as JSON?)?.array else {
                    throw .malformed(line: "release \(tag)", reason: "no asset listing")
                }
                var names: [Swift.String] = []
                for asset in assets {
                    guard let name = Swift.String(asset["name"] as JSON?) else {
                        throw .malformed(line: "release \(tag)", reason: "an asset has no name")
                    }
                    names.append(name)
                }
                return names
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
