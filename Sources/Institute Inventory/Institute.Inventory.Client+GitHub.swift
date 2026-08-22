internal import Byte_Primitives
internal import GitHub
public import Institute_Model
internal import JSON

extension Institute.Inventory {
    public static func client(
        _ execute: @escaping @Sendable ([Swift.String]) async throws(Transport.Error)
            -> Transport.Response = Transport.githubCLI
    ) -> Client<Transport.Error> {
        .init(
            repositories: .init { request async throws(Either<
                Async.Lifecycle.Error, GitHub.Organization.Repositories.Page.Error
            >) in
                let response: Transport.Response
                do {
                    response = try await execute([
                        "orgs/\(request.organization.underlying)/repos",
                        "-f", "type=\(request.type.rawValue)",
                        "-f", "per_page=\(request.size.rawValue)",
                        "-f", "page=\(request.page.rawValue)",
                    ])
                } catch {
                    throw .right(.transport)
                }
                guard (200..<300).contains(response.status) else {
                    throw .right(.malformedResponse)
                }
                let repositories: GitHub.Organization.Repositories.Response
                do {
                    repositories = try repositoryResponse(from: response.body ?? [])
                } catch {
                    throw .right(.malformedResponse)
                }

                let next: GitHub.Organization.Repositories.Request?
                if response.header("Link")?.contains(#"rel="next""#) == true {
                    let increment = request.page.rawValue.addingReportingOverflow(1)
                    guard
                        !increment.overflow,
                        let page = GitHub.Page.Number(rawValue: increment.partialValue)
                    else { throw .right(.malformedResponse) }
                    next = .init(
                        organization: request.organization,
                        type: request.type,
                        page: page,
                        size: request.size
                    )
                } else {
                    next = nil
                }
                return .init(response: repositories, next: next)
            },
            content: .init { request async throws(Transport.Error) in
                let path = request.path.segments.joined(separator: "/")
                let response = try await execute([
                    "repos/\(request.organization.underlying)/\(request.repository.underlying)"
                        + "/contents/\(path)"
                ])
                guard response.status != 404 else { return nil }
                guard (200..<300).contains(response.status) else {
                    throw .malformed("GitHub returned status \(response.status)")
                }
                do throws(JSON.Error) {
                    let json = try JSON.parse(response.body ?? [])
                    let rawKind = try Swift.String.deserialize(json["type"])
                    guard let kind = GitHub.Repository.Content.Kind(rawValue: rawKind) else {
                        throw JSON.Error.typeMismatch(
                            expected: "dir, file, submodule, or symlink content type",
                            got: rawKind
                        )
                    }
                    return .init(kind: kind)
                } catch {
                    throw .malformed("cannot decode GitHub content response: \(error)")
                }
            }
        )
    }
}

extension Institute.Inventory {
    private static func repositoryResponse(
        from body: [Byte]
    ) throws(JSON.Error) -> GitHub.Organization.Repositories.Response {
        let json = try JSON.parse(body)
        guard let elements = json.array else {
            throw JSON.Error.typeMismatch(expected: "array", got: "non-array")
        }

        var repositories = [GitHub.Repository.Summary]()
        repositories.reserveCapacity(elements.count)
        for element in elements {
            let rawID = try Swift.Int64.deserialize(element["id"])
            guard let id = Swift.UInt64(exactly: rawID) else {
                throw JSON.Error.typeMismatch(
                    expected: "nonnegative repository id",
                    got: Swift.String(rawID)
                )
            }
            let rawVisibility = try Swift.String.deserialize(element["visibility"])
            guard let visibility = GitHub.Repository.Visibility(rawValue: rawVisibility) else {
                throw JSON.Error.typeMismatch(
                    expected: "public, private, or internal visibility",
                    got: rawVisibility
                )
            }
            repositories.append(
                .init(
                    id: .init(id),
                    name: .init(try Swift.String.deserialize(element["name"])),
                    archived: try Swift.Bool.deserialize(element["archived"]),
                    disabled: try Swift.Bool.deserialize(element["disabled"]),
                    fork: try Swift.Bool.deserialize(element["fork"]),
                    visibility: visibility
                )
            )
        }
        return .init(repositories: repositories)
    }
}
