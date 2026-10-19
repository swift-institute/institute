public import Byte
import File_System
public import Institute_Model
import Process

import struct Swift.String

extension Institute.GitHub {
    /// The Process transport for authenticated GitHub REST operations,
    /// issued through `gh api -i`.
    ///
    /// `-i` is required, not cosmetic: response headers carry pagination
    /// (`Link`) and entity tags, and status codes distinguish contract
    /// states (404-as-absence) from refusals. `gh` supplies its own
    /// credential from the ambient `GH_TOKEN`; request bodies travel
    /// through a private temporary file because `gh api --input` is the
    /// CLI's one raw-body seam.
    public enum Transport {}
}

extension Institute.GitHub.Transport {
    public enum Error: Swift.Error, Sendable, CustomStringConvertible {
        /// The `gh` process could not be executed at all.
        case spawn(String)
        /// `gh` ran but exited abnormally with no response on stdout.
        case exit(String)
        /// `gh` succeeded but its output was not a parseable HTTP message.
        case malformed(String)
        /// A request body could not be staged for `--input`.
        case body(String)

        public var description: String {
            switch self {
            case .spawn(let message): return message
            case .exit(let message): return message
            case .malformed(let message): return message
            case .body(let message): return message
            }
        }
    }

    public struct Response: Sendable {
        public let status: Int
        /// Header field names lowercased; values with leading space trimmed.
        public let headers: [String: String]
        public let body: [Byte]

        public init(status: Int, headers: [String: String], body: [Byte]) {
            self.status = status
            self.headers = headers
            self.body = body
        }
    }

    /// Issues one request. A non-2xx status is returned, not thrown —
    /// the operation owner decides which statuses its contract admits.
    public static func request(
        method: String,
        path: String,
        body: [Byte]? = nil
    ) throws(Error) -> Response {
        var arguments = ["gh", "api", "-i", "--method", method]
        var bodyFile: File.Path? = nil
        if let body {
            let staged = try stage(body)
            bodyFile = staged
            arguments.append(contentsOf: ["--input", staged.description])
        }
        arguments.append(path)
        defer {
            if let bodyFile {
                // swift-linter:disable:next try optional
                // REASON: cleanup of a private temporary file; a failed
                // delete leaves only tmpdir residue and must not mask the
                // request's own outcome.
                try? File.System.Delete.delete(at: bodyFile)
            }
        }

        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: "/usr/bin/env",
                    arguments: arguments,
                    stdout: .pipe,
                    stderr: .pipe
                )
            )
        } catch {
            throw .spawn("cannot execute gh: \(error)")
        }
        guard case .exited(let code) = output.status else {
            throw .exit("gh did not exit normally: \(output.status)")
        }
        let stdout = output.stdout ?? []
        // `gh api` exits non-zero for non-2xx statuses while still
        // printing the full response; an empty stdout is the only
        // transport-level failure.
        guard !stdout.isEmpty else {
            let message = String(decoding: output.stderr ?? [], as: Swift.UTF8.self)
            throw .exit(
                "gh api \(method) \(path) exited \(code) and captured no response"
                    + (message.isEmpty ? "" : ": \(message)")
            )
        }
        return try parse(stdout)
    }

    /// Writes the body to a fresh private temporary file for `--input`.
    private static func stage(_ body: [Byte]) throws(Error) -> File.Path {
        let anchor: File.Path
        do throws(File.Path.Error) {
            anchor = try File.Path.Temporary.deterministic(
                prefix: "institute-github-body",
                key: "",
                suffix: ""
            )
        } catch {
            throw .body("could not resolve a temporary directory: \(error)")
        }
        let path: File.Path
        do throws(File.Path.Temporary.Error) {
            path = try File.Path.Temporary.sibling(
                of: anchor,
                prefix: "institute-github-body-",
                suffix: ".json"
            )
        } catch {
            throw .body("could not mint a temporary body path: \(error)")
        }
        do throws(File.System.Write.Atomic.Error) {
            try File(path).write.atomic(contentsOf: body)
        } catch {
            throw .body("could not stage the request body: \(error)")
        }
        return path
    }

    /// Parses `gh api -i` output: a status line, header fields, a blank
    /// line, then the body. Splitting is done over bytes: CRLF is one
    /// `Character` in Swift, so a character-based split never separates
    /// the header block from the body.
    internal static func parse(_ bytes: [UInt8]) throws(Error) -> Response {
        var lines: [[UInt8]] = []
        var current: [UInt8] = []
        for byte in bytes {
            if byte == 0x0A {
                if current.last == 0x0D { current.removeLast() }
                lines.append(current)
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(byte)
            }
        }
        if !current.isEmpty {
            if current.last == 0x0D { current.removeLast() }
            lines.append(current)
        }

        guard let statusBytes = lines.first, !statusBytes.isEmpty else {
            throw .malformed("gh produced no status line")
        }
        let statusLine = String(decoding: statusBytes, as: Swift.UTF8.self)
        lines.removeFirst()

        // "HTTP/2.0 200 OK" — take the second whitespace-separated field.
        let statusFields = statusLine.split(separator: " ", omittingEmptySubsequences: true)
        guard
            statusFields.count >= 2,
            let code = Swift.Int(statusFields[1])
        else {
            throw .malformed("cannot read a status code from \(statusLine)")
        }
        var fields: [String: String] = [:]
        var bodyIndex = lines.count
        for (index, lineBytes) in lines.enumerated() {
            if lineBytes.isEmpty {
                bodyIndex = index + 1
                break
            }
            let line = String(decoding: lineBytes, as: Swift.UTF8.self)
            guard let separator = line.firstIndex(of: ":") else {
                throw .malformed("cannot read a header field from \(line)")
            }
            let name = String(line[line.startIndex..<separator])
            var value = Substring(line[line.index(after: separator)...])
            while value.first == " " || value.first == "\t" {
                value = value.dropFirst()
            }
            fields[name.lowercased()] = String(value)
        }

        var body: [Byte] = []
        for (offset, lineBytes) in lines[bodyIndex...].enumerated() {
            if offset > 0 { body.append(Byte(0x0A)) }
            for byte in lineBytes { body.append(Byte(byte)) }
        }
        return .init(status: code, headers: fields, body: body)
    }
}
