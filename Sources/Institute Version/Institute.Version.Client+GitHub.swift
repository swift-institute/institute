import Byte
import Institute_GitHub
public import Institute_Model
import JSON

extension Institute.Version.Client {
    /// The live organizations, read and tagged through `gh api` with the
    /// ambient `GH_TOKEN`. Reads need only public access; the one write,
    /// a ref creation, needs `contents: write` on the repository.
    public static var github: Self {
        .init(
            subjects: { organization throws(Institute.Version.Error) in
                var subjects: [Institute.Version.Subject] = []
                var page = 1
                while true {
                    let path = "/orgs/\(organization.rawValue)/repos?type=all&per_page=100&page=\(page)"
                    let listing = try GitHub.array(try GitHub.get(path), at: path)
                    for repository in listing {
                        guard
                            let name = Swift.String(repository["name"] as JSON?),
                            let archived = Swift.Bool(repository["archived"]),
                            let isPrivate = Swift.Bool(repository["private"])
                        else {
                            throw .malformed("\(path) lists a repository without name, archived or private")
                        }
                        subjects.append(
                            .init(
                                repository: .init(organization: organization, name: name),
                                archived: archived,
                                private: isPrivate
                            )
                        )
                    }
                    guard listing.count == 100 else { return subjects }
                    page += 1
                }
            },
            head: { repository throws(Institute.Version.Error) in
                let path = "/repos/\(repository.description)/git/ref/heads/main"
                // 404: no `main`; 409: an empty repository.
                guard let reference = try GitHub.get(path, absent: [404, 409]) else { return nil }
                return try GitHub.commit(of: reference, in: repository, at: path)
            },
            tags: { repository, prefix throws(Institute.Version.Error) in
                var tags: [Institute.Version.Tag] = []
                var page = 1
                while true {
                    let path =
                        "/repos/\(repository.description)/git/matching-refs/tags/\(prefix)?per_page=100&page=\(page)"
                    let references = try GitHub.array(try GitHub.get(path), at: path)
                    for reference in references {
                        guard
                            let ref = Swift.String(reference["ref"] as JSON?),
                            ref.hasPrefix("refs/tags/")
                        else {
                            throw .malformed("\(path) lists a reference that is not a tag")
                        }
                        tags.append(
                            .init(
                                name: Swift.String(ref.dropFirst("refs/tags/".count)),
                                commit: try GitHub.commit(of: reference, in: repository, at: path)
                            )
                        )
                    }
                    guard references.count == 100 else { return tags }
                    page += 1
                }
            },
            gate: { repository, commit throws(Institute.Version.Error) in
                let runsPath =
                    "/repos/\(repository.description)/actions/runs?head_sha=\(commit)&branch=main&per_page=100"
                guard let runList = try GitHub.get(runsPath)["workflow_runs"].array else {
                    throw .malformed("\(runsPath) carries no workflow_runs")
                }
                var runs: [Institute.Version.Gate.Run] = []
                for run in runList {
                    guard
                        let suite = Swift.Int(run["check_suite_id"]),
                        let event = Swift.String(run["event"] as JSON?),
                        let branch = Swift.String(run["head_branch"] as JSON?),
                        let path = Swift.String(run["path"] as JSON?),
                        let status = Swift.String(run["status"] as JSON?)
                    else {
                        throw .malformed("\(runsPath) lists a run it cannot read")
                    }
                    runs.append(
                        .init(suite: suite, event: event, branch: branch, path: path, completed: status == "completed")
                    )
                }
                let checksPath =
                    "/repos/\(repository.description)/commits/\(commit)/check-runs"
                    + "?check_name=\(GitHub.query(Institute.Version.Gate.check))&filter=latest&per_page=100"
                guard let checkList = try GitHub.get(checksPath)["check_runs"].array else {
                    throw .malformed("\(checksPath) carries no check_runs")
                }
                var checks: [Institute.Version.Gate.Check] = []
                for check in checkList {
                    guard
                        let suite = Swift.Int(check["check_suite"]["id"]),
                        let status = Swift.String(check["status"] as JSON?)
                    else {
                        throw .malformed("\(checksPath) lists a check run it cannot read")
                    }
                    checks.append(
                        .init(
                            suite: suite,
                            completed: status == "completed",
                            conclusion: Swift.String(check["conclusion"] as JSON?)
                        )
                    )
                }
                return .init(runs: runs, checks: checks)
            },
            relation: { repository, base, head throws(Institute.Version.Error) in
                let path = "/repos/\(repository.description)/compare/\(base)...\(head)?per_page=1"
                guard
                    let status = Swift.String(try GitHub.get(path)["status"] as JSON?),
                    let relation = Institute.Version.Relation(rawValue: status)
                else {
                    throw .malformed("\(path) carries no known status")
                }
                return relation
            },
            create: { repository, tag throws(Institute.Version.Error) in
                guard GitHub.isCommit(tag.commit), !tag.name.isEmpty,
                    tag.name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || ".-".contains($0)) })
                else {
                    throw .malformed("refusing to create tag '\(tag.name)' on '\(tag.commit)'")
                }
                let path = "/repos/\(repository.description)/git/refs"
                let body = [Byte](utf8: "{\"ref\":\"refs/tags/\(tag.name)\",\"sha\":\"\(tag.commit)\"}")
                let response = try GitHub.request(method: "POST", path: path, body: body)
                switch response.status {
                case 201:
                    return .created
                case 422:
                    // The name exists: report what it names, never replace it.
                    let existing = "/repos/\(repository.description)/git/ref/tags/\(tag.name)"
                    guard let reference = try GitHub.get(existing, absent: [404]) else {
                        throw .status(method: "POST", path: path, status: 422)
                    }
                    return .exists(commit: try GitHub.commit(of: reference, in: repository, at: existing))
                default:
                    throw .status(method: "POST", path: path, status: response.status)
                }
            }
        )
    }
}

extension Institute.Version.Client {
    /// The `gh api` reads and the one write the GitHub binding composes.
    fileprivate enum GitHub {
        static func request(
            method: Swift.String,
            path: Swift.String,
            body: [Byte]? = nil
        ) throws(Institute.Version.Error) -> Institute.GitHub.Transport.Response {
            do throws(Institute.GitHub.Transport.Error) {
                return try Institute.GitHub.Transport.request(method: method, path: path, body: body)
            } catch {
                throw .transport(error.description)
            }
        }

        static func get(_ path: Swift.String) throws(Institute.Version.Error) -> JSON {
            guard let json = try get(path, absent: []) else {
                throw .status(method: "GET", path: path, status: 404)
            }
            return json
        }

        /// The JSON at `path`, or nil when the status is one of `absent`.
        static func get(_ path: Swift.String, absent: Swift.Set<Swift.Int>) throws(Institute.Version.Error) -> JSON? {
            let response = try request(method: "GET", path: path)
            if absent.contains(response.status) { return nil }
            guard response.status == 200 else {
                throw .status(method: "GET", path: path, status: response.status)
            }
            do throws(JSON.Error) {
                return try JSON.parse(response.body)
            } catch {
                throw .malformed("\(path) is not JSON: \(error)")
            }
        }

        static func array(_ json: JSON, at path: Swift.String) throws(Institute.Version.Error) -> [JSON] {
            guard let array = json.array else { throw .malformed("\(path) is not an array") }
            return array
        }

        /// The commit a git reference names, reading annotated tags
        /// through to the commit they tag.
        static func commit(
            of reference: JSON,
            in repository: Institute.Repository.Coordinate,
            at path: Swift.String
        ) throws(Institute.Version.Error) -> Swift.String {
            var object = reference["object"]
            var location = path
            // An annotated tag may tag another tag; a chain longer than a
            // handful is not something a person made.
            for _ in 0..<8 {
                guard
                    let sha = Swift.String(object["sha"] as JSON?), isCommit(sha),
                    let type = Swift.String(object["type"] as JSON?)
                else {
                    throw .malformed("\(location) names no object")
                }
                switch type {
                case "commit":
                    return sha
                case "tag":
                    location = "/repos/\(repository.description)/git/tags/\(sha)"
                    object = try get(location)["object"]
                default:
                    throw .malformed("\(location) names a \(type), not a commit")
                }
            }
            throw .malformed("\(path) is a chain of annotated tags too long to follow")
        }

        static func isCommit(_ sha: Swift.String) -> Swift.Bool {
            sha.count == 40 && sha.allSatisfy { "0123456789abcdef".contains($0) }
        }

        /// Percent-encodes a query value: everything outside the unreserved set.
        static func query(_ value: Swift.String) -> Swift.String {
            var encoded = ""
            for byte in value.utf8 {
                let scalar = Swift.Unicode.Scalar(byte)
                if scalar.isASCII, scalar.properties.isAlphabetic || scalar.properties.numericType != nil
                    || "-._~".unicodeScalars.contains(scalar)
                {
                    encoded.unicodeScalars.append(scalar)
                } else {
                    let hex = Swift.String(byte, radix: 16, uppercase: true)
                    encoded += "%" + (hex.count == 1 ? "0" + hex : hex)
                }
            }
            return encoded
        }
    }
}
