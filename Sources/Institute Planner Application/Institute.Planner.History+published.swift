public import Institute_Model
import JSON

extension Institute.Planner.History {
    /// The live institute-application main-branch graph, read through GitHub's
    /// public compare endpoint without a credential.
    public static var published: Self {
        .init { revision, pinned throws(Institute.Planner.Error) in
            guard try follows(revision, pinned) else { return false }
            return try followsMain(revision)
        }
    }

    private static func follows(
        _ revision: Institute.Planner.Revision,
        _ pinned: Institute.Planner.Revision
    ) throws(Institute.Planner.Error) -> Swift.Bool {
        try status(from: pinned.description, through: revision.description)
    }

    private static func followsMain(
        _ revision: Institute.Planner.Revision
    ) throws(Institute.Planner.Error) -> Swift.Bool {
        try status(from: revision.description, through: "main")
    }

    private static func status(
        from base: Swift.String,
        through head: Swift.String
    ) throws(Institute.Planner.Error) -> Swift.Bool {
        let repository = Institute.Planner.publisher
        let address = "https://api.github.com/repos/\(repository)/compare/\(base)...\(head)"
        let bytes = try Institute.Planner.Curl.get(address)
        let response: JSON
        do throws(JSON.Error) {
            response = try JSON.parse(bytes)
        } catch {
            throw .malformed(line: "compare \(base)...\(head)", reason: "not JSON: \(error)")
        }
        guard let status = Swift.String(response["status"] as JSON?) else {
            throw .malformed(line: "compare \(base)...\(head)", reason: "no status")
        }
        return status == "ahead" || status == "identical"
    }
}
