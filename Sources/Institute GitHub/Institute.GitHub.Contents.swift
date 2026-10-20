public import Byte
public import Institute_Model
import JSON
import RFC_4648

import struct Swift.String

extension Institute.GitHub {
    /// Repository file contents at a ref, read through the `gh api`
    /// transport's contents endpoint.
    public enum Contents {}
}

extension Institute.GitHub.Contents {
    /// The bytes of the regular file at `path` in `repository` at `ref`.
    public static func read(
        repository: Swift.String,
        path: Swift.String,
        ref: Swift.String
    ) throws(Institute.GitHub.Release.Error) -> [Byte] {
        let location = "/repos/\(repository)/contents/\(path)?ref=\(ref)"
        let response: Institute.GitHub.Transport.Response
        do throws(Institute.GitHub.Transport.Error) {
            response = try Institute.GitHub.Transport.request(method: "GET", path: location)
        } catch {
            throw .transport(error)
        }
        if response.status == 404 { throw .missing("\(repository) has no \(path) at \(ref)") }
        guard response.status == 200 else {
            throw .status(path: location, status: response.status)
        }
        let content: JSON
        do throws(JSON.Error) {
            content = try JSON.parse(response.body)
        } catch {
            throw .malformed("\(location) is not JSON: \(error)")
        }
        guard
            Swift.String(content["type"] as JSON?) == "file",
            Swift.String(content["encoding"] as JSON?) == "base64",
            let encoded = Swift.String(content["content"] as JSON?),
            let bytes = encoded.base64.decoded(strictness: .lenient)
        else {
            throw .malformed("\(repository): \(path) at \(ref) is not a base64 regular file")
        }
        return bytes
    }
}
