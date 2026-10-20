public import Byte
public import File_System
public import Institute_Model
import JSON
import Process

import struct Swift.String

extension Institute.GitHub {
    /// The assets of one GitHub release: their names, read through the
    /// `gh api` transport, and their bytes, downloaded through
    /// `gh release download`.
    ///
    /// The transport's response parser normalizes line endings, which is
    /// right for JSON and wrong for a binary asset, so asset bytes travel
    /// through `gh release download` into a file instead.
    public enum Release {}
}

extension Institute.GitHub.Release {
    /// Every asset name on the release `tag` of `repository`, across all
    /// pages of the release-assets listing.
    public static func assets(
        repository: Swift.String,
        tag: Swift.String
    ) throws(Error) -> [Swift.String] {
        let release = try object("/repos/\(repository)/releases/tags/\(tag)")
        guard let identifier = Swift.Int(release["id"]) else {
            throw .malformed("release \(tag) of \(repository) carries no numeric id")
        }
        var names: [Swift.String] = []
        var page = 1
        while true {
            let path = "/repos/\(repository)/releases/\(identifier)/assets?per_page=100&page=\(page)"
            guard let assets = try object(path).array else {
                throw .malformed("\(path) is not an array")
            }
            for asset in assets {
                guard let name = Swift.String(asset["name"] as JSON?) else {
                    throw .malformed("\(path) lists an asset without a name")
                }
                names.append(name)
            }
            guard assets.count == 100 else { return names }
            page += 1
        }
    }

    /// Downloads the asset named `asset` of release `tag` to `destination`,
    /// replacing any file there.
    public static func download(
        repository: Swift.String,
        tag: Swift.String,
        asset: Swift.String,
        to destination: File.Path
    ) throws(Error) {
        // `gh release download --pattern` matches a glob; an asset name
        // carrying a glob metacharacter could select a different asset.
        guard !asset.isEmpty, !asset.contains(where: { "*?[]".contains($0) }) else {
            throw .malformed("asset name \(asset) is not an exact name")
        }
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: "/usr/bin/env",
                    arguments: [
                        "gh", "release", "download", tag,
                        "--repo", repository,
                        "--pattern", asset,
                        "--output", destination.description,
                        "--clobber",
                    ],
                    stdout: .pipe,
                    stderr: .pipe
                )
            )
        } catch {
            throw .transport(.spawn("cannot execute gh: \(error)"))
        }
        guard output.status == .exited(code: 0) else {
            let message = Swift.String(decoding: output.stderr ?? [], as: Swift.UTF8.self)
            throw .missing("\(repository) release \(tag) has no downloadable asset \(asset): \(message)")
        }
    }

    private static func object(_ path: Swift.String) throws(Error) -> JSON {
        let response: Institute.GitHub.Transport.Response
        do throws(Institute.GitHub.Transport.Error) {
            response = try Institute.GitHub.Transport.request(method: "GET", path: path)
        } catch {
            throw .transport(error)
        }
        guard response.status == 200 else {
            throw .status(path: path, status: response.status)
        }
        do throws(JSON.Error) {
            return try JSON.parse(response.body)
        } catch {
            throw .malformed("\(path) is not JSON: \(error)")
        }
    }
}
