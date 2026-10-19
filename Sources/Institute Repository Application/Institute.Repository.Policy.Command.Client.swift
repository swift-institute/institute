public import Byte
public import Institute_GitHub
public import Institute_Model
public import Institute_Repository_Policy
import JSON
import RFC_4648

import struct Swift.String

extension Institute.Repository.Policy.Command {
    /// The executing client behind both wave contracts, issuing every
    /// operation through the application's `gh api` transport. The domain
    /// owns the contracts and every mutation precondition; this type owns
    /// only transport, decoding, pagination, and bounded retry.
    public struct Client: Sendable {
        public typealias Error = Institute.Repository.Policy.Client.Error

        /// One raw request: method, path, body. Defaults to the `gh api`
        /// transport; tests inject a deterministic seam here.
        public typealias Execute =
            @Sendable (
                Swift.String, Swift.String, [Byte]?
            ) async throws(Institute.GitHub.Transport.Error) -> Institute.GitHub.Transport.Response

        let maximumAttempts: Int
        let delaySeconds: Int
        let execute: Execute

        public init(
            maximumAttempts: Int = 4,
            delaySeconds: Int = 2,
            execute: @escaping Execute = { method, path, body in
                try Institute.GitHub.Transport.request(method: method, path: path, body: body)
            }
        ) {
            self.maximumAttempts = maximumAttempts
            self.delaySeconds = delaySeconds
            self.execute = execute
        }
    }
}

extension Institute.Repository.Policy.Command.Client {
    typealias Response = Institute.GitHub.Transport.Response

    func request(
        method: Swift.String,
        path: Swift.String,
        body: [Byte]? = nil,
        retries: Bool? = nil
    ) async throws(Error) -> Response {
        let mayRetry = retries ?? (method == "GET")
        var attempt = 1
        while true {
            let response: Response
            do throws(Institute.GitHub.Transport.Error) {
                response = try await execute(method, path, body)
            } catch {
                guard mayRetry, attempt < maximumAttempts else {
                    throw .transport(path: path, message: error.description)
                }
                await pause(seconds: delaySeconds << max(0, attempt - 1))
                attempt += 1
                continue
            }
            if mayRetry, Self.retryable(response.status), attempt < maximumAttempts {
                await pause(seconds: retryDelay(headers: response.headers, attempt: attempt))
                attempt += 1
                continue
            }
            return response
        }
    }

    static func retryable(_ status: Int) -> Bool {
        status == 429 || status == 500 || status == 502 || status == 503 || status == 504
    }

    func retryDelay(headers: [Swift.String: Swift.String], attempt: Int) -> Int {
        headers["retry-after"].flatMap(Int.init) ?? delaySeconds << max(0, attempt - 1)
    }

    func pause(seconds: Int) async {
        guard seconds > 0 else { return }
        do {
            try await Task.sleep(for: .seconds(seconds))
        } catch {
            return
        }
    }

    func error(
        method: Swift.String,
        path: Swift.String,
        response: Response
    ) -> Error {
        .http(
            method: method,
            path: path,
            status: response.status,
            response: Swift.String(response.body.prefix(2_000))
        )
    }

    func json(
        _ response: Response,
        path: Swift.String
    ) throws(Error) -> JSON {
        do throws(JSON.Error) {
            return try JSON.parse(response.body)
        } catch {
            throw .decoding(path: path, message: "\(error)")
        }
    }

    func decode<T: Swift.Decodable>(
        _ type: T.Type,
        from response: Response,
        path: Swift.String
    ) throws(Error) -> T {
        let value = try json(response, path: path)
        do throws(Swift.DecodingError) {
            return try value.decode(type)
        } catch {
            throw .decoding(path: path, message: "\(error)")
        }
    }

    /// The `page` query value of the RFC 8288 `rel="next"` link, when one
    /// is advertised.
    func nextPage(_ headers: [Swift.String: Swift.String]) throws(Error) -> Int? {
        guard
            let link = headers["link"],
            let field = link.split(separator: ",").first(where: { $0.contains("rel=\"next\"") })
        else { return nil }
        guard
            let start = field.firstIndex(of: "<"),
            let end = field[start...].firstIndex(of: ">")
        else {
            throw .precondition("GitHub pagination Link field was invalid")
        }
        let url = field[field.index(after: start)..<end]
        guard let query = url.firstIndex(of: "?") else {
            throw .precondition("GitHub pagination Link field was invalid")
        }
        for parameter in url[url.index(after: query)...].split(separator: "&") {
            let pair = parameter.split(separator: "=", maxSplits: 1)
            if pair.count == 2, pair[0] == "page", let value = Swift.Int(pair[1]), value > 0 {
                return value
            }
        }
        throw .precondition("GitHub pagination Link field was invalid")
    }

    func publicRepositoryCount(
        organization: Swift.String
    ) async throws(Error) -> Int {
        let path = "/orgs/\(organization)"
        let response = try await request(method: "GET", path: path)
        guard response.status == 200 else {
            throw error(method: "GET", path: path, response: response)
        }
        let value = try json(response, path: path)
        guard let count = Swift.Int(value["public_repos"]) else {
            throw .decoding(path: path, message: "public_repos is not an integer")
        }
        return count
    }

    func base64Bytes(
        _ encoded: Swift.String,
        subject: Swift.String
    ) throws(Error) -> [Byte] {
        guard let bytes = encoded.base64.decoded(strictness: .lenient) else {
            throw .precondition(subject)
        }
        return bytes
    }
}

extension Institute.Repository.Policy.Command.Client: Institute.Repository.Policy.Caller.Wave.Client {
    public func capacity(
        requiredRequests: Int
    ) async throws(Error) -> Institute.Repository.Policy.Caller.Wave.Capacity {
        guard requiredRequests > 0 else {
            throw .precondition("caller-wave required request capacity must be positive")
        }
        let path = "/rate_limit"
        let response = try await request(method: "GET", path: path)
        guard response.status == 200 else {
            throw error(method: "GET", path: path, response: response)
        }
        let core = try json(response, path: path)["resources"]["core"]
        guard
            let remaining = Swift.Int(core["remaining"]),
            let reset = Swift.Int(core["reset"])
        else {
            throw .decoding(path: path, message: "rate-limit core facts are not integers")
        }
        return .init(remaining: remaining, required: requiredRequests, resetAt: reset)
    }

    public func waveRepositories(
        organization: Swift.String
    ) async throws(Error) -> Institute.Repository.Policy.Caller.Wave.Listing {
        let expectedBefore = try await publicRepositoryCount(organization: organization)
        var page = 1
        var result = [Institute.Repository.Policy.Repository]()
        var visited: Set<Int> = []
        while true {
            guard visited.insert(page).inserted else {
                throw .precondition(
                    "\(organization): repository pagination repeated page \(page)"
                )
            }
            let path = "/orgs/\(organization)/repos?type=public&per_page=100&page=\(page)"
            let response = try await request(method: "GET", path: path)
            guard response.status == 200 else {
                throw error(method: "GET", path: path, response: response)
            }
            let repositories = try decode(
                [Institute.Repository.Policy.Repository].self,
                from: response,
                path: path
            )
            result.append(contentsOf: repositories)
            guard let next = try nextPage(response.headers) else { break }
            guard next == page + 1 else {
                throw .precondition(
                    "\(organization): repository pagination advanced from page \(page) to \(next)"
                )
            }
            page = next
        }
        let expectedAfter = try await publicRepositoryCount(organization: organization)
        guard expectedBefore == expectedAfter else {
            throw .precondition(
                "\(organization): public repository count moved from \(expectedBefore) "
                    + "to \(expectedAfter) during enumeration"
            )
        }
        guard result.count == expectedAfter else {
            throw .precondition(
                "\(organization): enumerated \(result.count) public repositories; "
                    + "organization reports \(expectedAfter)"
            )
        }
        guard Set(result.map(\.id)).count == result.count,
            Set(result.map { $0.fullName.lowercased() }).count == result.count
        else {
            throw .precondition("\(organization): repository pagination returned duplicates")
        }
        return .init(repositories: result, expected: expectedAfter)
    }

    public func rootManifest(
        _ repository: Swift.String,
        head: Swift.String
    ) async throws(Error) -> Institute.Repository.Policy.Caller.Wave.Manifest? {
        let path = "/repos/\(repository)/contents/Package.swift?ref=\(head)"
        let response = try await request(method: "GET", path: path)
        if response.status == 404 { return nil }
        guard response.status == 200 else {
            throw error(method: "GET", path: path, response: response)
        }
        let content = try json(response, path: path)
        guard
            let kind = Swift.String(content["type"] as JSON?),
            let blob = Swift.String(content["sha"] as JSON?)
        else {
            throw .decoding(path: path, message: "content facts are incomplete")
        }
        return .init(kind: kind, blob: blob)
    }

    public func waveRepository(
        _ name: Swift.String
    ) async throws(Error) -> Institute.Repository.Policy.Caller.Wave.Repository {
        let path = "/repos/\(name)"
        let response = try await request(method: "GET", path: path)
        guard response.status == 200 else {
            throw error(method: "GET", path: path, response: response)
        }
        let value = try json(response, path: path)
        guard
            let id = Swift.Int64(value["id"]),
            let visibility = Swift.String(value["visibility"] as JSON?),
            let archived = Swift.Bool(value["archived"]),
            let disabled = Swift.Bool(value["disabled"]),
            let defaultBranch = Swift.String(value["default_branch"] as JSON?)
        else {
            throw .decoding(path: path, message: "repository facts are incomplete")
        }
        return .init(
            id: id,
            visibility: visibility,
            archived: archived,
            disabled: disabled,
            defaultBranch: defaultBranch
        )
    }

    public func head(
        _ repository: Swift.String
    ) async throws(Error) -> Swift.String {
        let path = "/repos/\(repository)/git/ref/heads/main"
        let response = try await request(method: "GET", path: path)
        guard response.status == 200 else {
            throw error(method: "GET", path: path, response: response)
        }
        guard let sha = Swift.String(try json(response, path: path)["object"]["sha"] as JSON?)
        else {
            throw .decoding(path: path, message: "reference facts are incomplete")
        }
        return sha
    }

    public func callerSource(
        _ repository: Swift.String,
        head: Swift.String
    ) async throws(Error) -> Institute.Repository.Policy.Caller.Wave.CallerSource {
        guard let source = try await callerSourceIfPresent(repository, head: head) else {
            throw .precondition("\(repository): required package caller is absent")
        }
        return source
    }

    public func callerSourceIfPresent(
        _ repository: Swift.String,
        head: Swift.String
    ) async throws(Error) -> Institute.Repository.Policy.Caller.Wave.CallerSource? {
        let path = "/repos/\(repository)/contents/.github/workflows/ci.yml?ref=\(head)"
        let response = try await request(method: "GET", path: path)
        if response.status == 404 { return nil }
        guard response.status == 200 else {
            throw error(method: "GET", path: path, response: response)
        }
        let content = try json(response, path: path)
        guard
            Swift.String(content["encoding"] as JSON?) == "base64",
            let blob = Swift.String(content["sha"] as JSON?),
            let encoded = Swift.String(content["content"] as JSON?)
        else {
            throw .precondition("\(repository): caller content is not base64")
        }
        return .init(
            blob: blob,
            bytes: try base64Bytes(encoded, subject: "\(repository): caller content is not base64")
        )
    }

    public func rulesets(
        _ repository: Swift.String
    ) async throws(Error) -> [Institute.Repository.Policy.Caller.Wave.RulesetReference] {
        var page = 1
        var result: [Institute.Repository.Policy.Caller.Wave.RulesetReference] = []
        var visited: Set<Int> = []
        while true {
            guard visited.insert(page).inserted else {
                throw .precondition("\(repository): ruleset pagination repeated page \(page)")
            }
            let path = "/repos/\(repository)/rulesets?per_page=100&page=\(page)"
            let response = try await request(method: "GET", path: path)
            guard response.status == 200 else {
                throw error(method: "GET", path: path, response: response)
            }
            guard let records = try json(response, path: path).array else {
                throw .decoding(path: path, message: "rulesets are not an array")
            }
            for record in records {
                guard
                    let id = Swift.Int64(record["id"]),
                    let name = Swift.String(record["name"] as JSON?)
                else {
                    throw .decoding(path: path, message: "ruleset reference is incomplete")
                }
                result.append(.init(id: id, name: name))
            }
            guard let next = try nextPage(response.headers) else { return result }
            guard next == page + 1 else {
                throw .precondition(
                    "\(repository): ruleset pagination advanced from page \(page) to \(next)"
                )
            }
            page = next
        }
    }

    public func ruleset(
        _ repository: Swift.String,
        id: Int64
    ) async throws(Error) -> [Byte] {
        let path = "/repos/\(repository)/rulesets/\(id)"
        let response = try await request(method: "GET", path: path)
        guard response.status == 200 else {
            throw error(method: "GET", path: path, response: response)
        }
        return response.body
    }

    public func replaceRuleset(
        _ repository: Swift.String,
        id: Int64,
        payload: [Byte]
    ) async throws(Error) {
        let path = "/repos/\(repository)/rulesets/\(id)"
        let response = try await request(method: "PUT", path: path, body: payload)
        guard response.status == 200 else {
            throw error(method: "PUT", path: path, response: response)
        }
    }

    public func createRuleset(
        _ repository: Swift.String,
        payload: [Byte]
    ) async throws(Error) -> Int64 {
        let path = "/repos/\(repository)/rulesets"
        let response = try await request(method: "POST", path: path, body: payload)
        guard response.status == 201 else {
            throw error(method: "POST", path: path, response: response)
        }
        guard let id = Swift.Int64(try json(response, path: path)["id"]) else {
            throw .decoding(path: path, message: "created ruleset has no id")
        }
        return id
    }

    public func createBlob(
        _ repository: Swift.String,
        content: [Byte]
    ) async throws(Error) -> Swift.String {
        let path = "/repos/\(repository)/git/blobs"
        let body: JSON = [
            "content": content.base64.encoded().json,
            "encoding": "base64",
        ]
        let response = try await request(
            method: "POST",
            path: path,
            body: [Byte](utf8: body.serialize(sortKeys: true))
        )
        guard response.status == 201 else {
            throw error(method: "POST", path: path, response: response)
        }
        guard let sha = Swift.String(try json(response, path: path)["sha"] as JSON?) else {
            throw .decoding(path: path, message: "created blob has no sha")
        }
        return sha
    }

    public func createCommit(
        _ repository: Swift.String,
        parent: Swift.String,
        blob: Swift.String,
        message: Swift.String
    ) async throws(Error) -> Swift.String {
        let tree = try await createTree(
            repository,
            parent: parent,
            entries: [
                [
                    "path": ".github/workflows/ci.yml".json,
                    "mode": "100644",
                    "type": "blob",
                    "sha": blob.json,
                ]
            ]
        )
        return try await mint(repository, tree: tree, parent: parent, message: message)
    }

    public func moveMain(
        _ repository: Swift.String,
        to head: Swift.String
    ) async throws(Error) {
        let path = "/repos/\(repository)/git/refs/heads/main"
        let body: JSON = ["sha": head.json, "force": false]
        let response = try await request(
            method: "PATCH",
            path: path,
            body: [Byte](utf8: body.serialize(sortKeys: true))
        )
        guard response.status == 200 else {
            throw error(method: "PATCH", path: path, response: response)
        }
    }

    public func pause(attempt: Int) async {
        await pause(seconds: delaySeconds << max(0, attempt - 1))
    }
}

extension Institute.Repository.Policy.Command.Client:
    Institute.Repository.Policy.Uniformity.Wave.Client
{
    public func shapeFile(
        _ repository: Swift.String,
        path filePath: Swift.String,
        head: Swift.String
    ) async throws(Error) -> Institute.Repository.Policy.Uniformity.Wave.File? {
        let path = "/repos/\(repository)/contents/\(filePath)?ref=\(head)"
        let response = try await request(method: "GET", path: path)
        if response.status == 404 { return nil }
        guard response.status == 200 else {
            throw error(method: "GET", path: path, response: response)
        }
        let content = try json(response, path: path)
        guard
            Swift.String(content["type"] as JSON?) == "file",
            Swift.String(content["encoding"] as JSON?) == "base64",
            let blob = Swift.String(content["sha"] as JSON?),
            let encoded = Swift.String(content["content"] as JSON?)
        else {
            throw .precondition(
                "\(repository): \(filePath) content is not a base64 regular file"
            )
        }
        return .init(
            blob: blob,
            bytes: try base64Bytes(
                encoded,
                subject: "\(repository): \(filePath) content is not a base64 regular file"
            )
        )
    }

    public func createShapeCommit(
        _ repository: Swift.String,
        parent: Swift.String,
        gitignoreBlob: Swift.String,
        deletions: [Swift.String],
        message: Swift.String
    ) async throws(Error) -> Swift.String {
        var entries: [JSON] = [
            [
                "path": Institute.Repository.Policy.Uniformity.Wave.Shape.gitignorePath.json,
                "mode": "100644",
                "type": "blob",
                "sha": gitignoreBlob.json,
            ]
        ]
        for deletion in deletions {
            // A null sha in a tree entry deletes the path from the base
            // tree; this is the API's exact deletion form.
            entries.append(
                [
                    "path": deletion.json,
                    "mode": "100644",
                    "type": "blob",
                    "sha": .null,
                ]
            )
        }
        let tree = try await createTree(repository, parent: parent, entries: entries)
        return try await mint(repository, tree: tree, parent: parent, message: message)
    }
}

extension Institute.Repository.Policy.Command.Client {
    /// One tree over `parent`'s base tree with exactly `entries`.
    func createTree(
        _ repository: Swift.String,
        parent: Swift.String,
        entries: [JSON]
    ) async throws(Error) -> Swift.String {
        let commitPath = "/repos/\(repository)/git/commits/\(parent)"
        let commitResponse = try await request(method: "GET", path: commitPath)
        guard commitResponse.status == 200 else {
            throw error(method: "GET", path: commitPath, response: commitResponse)
        }
        guard
            let baseTree = Swift.String(
                try json(commitResponse, path: commitPath)["tree"]["sha"] as JSON?
            )
        else {
            throw .decoding(path: commitPath, message: "parent commit has no tree")
        }

        let treePath = "/repos/\(repository)/git/trees"
        let treeBody: JSON = [
            "base_tree": baseTree.json,
            "tree": .array(entries),
        ]
        let treeResponse = try await request(
            method: "POST",
            path: treePath,
            body: [Byte](utf8: treeBody.serialize(sortKeys: true))
        )
        guard treeResponse.status == 201 else {
            throw error(method: "POST", path: treePath, response: treeResponse)
        }
        guard let sha = Swift.String(try json(treeResponse, path: treePath)["sha"] as JSON?)
        else {
            throw .decoding(path: treePath, message: "created tree has no sha")
        }
        return sha
    }

    /// One commit over `tree` with exactly `parent`.
    func mint(
        _ repository: Swift.String,
        tree: Swift.String,
        parent: Swift.String,
        message: Swift.String
    ) async throws(Error) -> Swift.String {
        let createPath = "/repos/\(repository)/git/commits"
        let createBody: JSON = [
            "message": message.json,
            "tree": tree.json,
            "parents": [parent.json],
        ]
        let createResponse = try await request(
            method: "POST",
            path: createPath,
            body: [Byte](utf8: createBody.serialize(sortKeys: true))
        )
        guard createResponse.status == 201 else {
            throw error(method: "POST", path: createPath, response: createResponse)
        }
        guard
            let sha = Swift.String(try json(createResponse, path: createPath)["sha"] as JSON?)
        else {
            throw .decoding(path: createPath, message: "created commit has no sha")
        }
        return sha
    }
}
