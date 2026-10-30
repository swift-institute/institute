import Byte
import File_System
public import Institute_CI_Model
public import Institute_Model
import JSON
import Process

import struct Swift.String

extension Institute.CI.Package {
    /// Complete GitHub event-diff retrieval for package-work planning.
    /// Workflow wiring passes coordinates only; pagination and classification
    /// live here, beside the `Content` classifier they feed.
    public enum Diff {
        enum Error: Swift.Error { case event, comparison, response }

        /// GitHub's pull-files endpoint stops after this many records. An
        /// advertised count at the limit cannot prove that the list is
        /// complete, even when the decoded response contains 3,000 records.
        static let pullRequestFileLimit = 3_000

        public static func packageContentChanged(
            event: Swift.String,
            eventPath: Swift.String,
            repository: Swift.String,
            workspace: Swift.String
        ) -> Bool {
            do throws(Error) {
                let payload = try eventPayload(at: eventPath)
                return packageContentChanged(
                    event: event,
                    payload: payload,
                    repository: repository,
                    workspace: workspace,
                    response: response(at:)
                )
            } catch { return true }
        }

        static func packageContentChanged(
            event: Swift.String,
            payload: [Swift.String: JSON],
            repository: Swift.String,
            workspace: Swift.String,
            response: (Swift.String) throws(Error) -> JSON
        ) -> Bool {
            guard event == "pull_request" || event == "push" else { return true }
            do throws(Error) {
                let changes: [Content.Change]
                if event == "pull_request" {
                    guard let number = Swift.Int(payload["number"] ?? .null), number > 0,
                        let pullRequest = payload["pull_request"]?.dictionary,
                        let expected = Swift.Int(pullRequest["changed_files"] ?? .null),
                        expected >= 0, expected < pullRequestFileLimit
                    else { throw .event }
                    changes = try pullRequestFiles(
                        at: "repos/\(repository)/pulls/\(number)/files?per_page=100",
                        expected: expected,
                        response: response
                    )
                } else {
                    guard let before = Swift.String(payload["before"]),
                        let after = Swift.String(payload["after"]),
                        !isZero(before), !isZero(after)
                    else { throw .comparison }
                    changes = try pushChanges(
                        repository: repository,
                        before: before,
                        after: after,
                        response: response
                    )
                }
                return Content(
                    declaredRoots: packageRoots(in: workspace)
                )
                .changed(changes)
            } catch { return true }
        }

        static func eventPayload(at path: Swift.String) throws(Error) -> [Swift.String: JSON] {
            guard let text = text(atPath: path) else { throw .event }
            let value: JSON
            do throws(JSON.Error) {
                value = try JSON.parse(text)
            } catch {
                throw .event
            }
            guard let payload = value.dictionary else { throw .event }
            return payload
        }

        static func pushChanges(
            repository: Swift.String,
            before: Swift.String,
            after: Swift.String,
            response: (Swift.String) throws(Error) -> JSON
        ) throws(Error) -> [Content.Change] {
            let pages = try objects(
                at: "repos/\(repository)/compare/\(before)...\(after)?per_page=100",
                response: response
            )
            guard !pages.isEmpty else { throw .comparison }
            guard let expected = Swift.Int(pages[0]["total_commits"] ?? .null), expected >= 0
            else {
                throw .comparison
            }
            var commits: [Swift.String] = []
            for page in pages {
                guard Swift.Int(page["total_commits"] ?? .null) == expected,
                    let records = page["commits"]?.array
                else { throw .comparison }
                for record in records {
                    guard let sha = Swift.String(record["sha"] as JSON?),
                        !sha.isEmpty
                    else { throw .comparison }
                    commits.append(sha)
                }
            }
            guard commits.count == expected, Set(commits).count == expected else {
                throw .comparison
            }
            var changes: [Content.Change] = []
            for commit in commits {
                changes += try files(
                    at: "repos/\(repository)/commits/\(commit)?per_page=100",
                    response: response
                )
            }
            return changes
        }

        /// The event's advertised cardinality binds the paginated response.
        /// Without it, a capped or short response can be valid JSON and still
        /// be incomplete. Duplicate filenames are ambiguous as well: GitHub
        /// advertises a pull request's changed files as distinct records.
        static func pullRequestFiles(
            at endpoint: Swift.String,
            expected: Int,
            response: (Swift.String) throws(Error) -> JSON
        ) throws(Error) -> [Content.Change] {
            let changes = try files(at: endpoint, response: response)
            guard changes.count == expected,
                Set(changes).count == expected,
                Set(changes.map(\.path)).count == expected
            else { throw .response }
            return changes
        }

        static func files(
            at endpoint: Swift.String,
            response: (Swift.String) throws(Error) -> JSON
        ) throws(Error) -> [Content.Change] {
            var changes: [Content.Change] = []
            for page in try pages(from: response(endpoint)) {
                let records: [JSON]
                if page.isObject {
                    guard let files = page["files"].array else { throw .response }
                    records = files
                } else if let array = page.array {
                    records = array
                } else {
                    throw .response
                }
                for record in records {
                    guard record.isObject,
                        let path = Swift.String(record["filename"] as JSON?),
                        !path.isEmpty
                    else { throw .response }
                    let previousPath: Swift.String?
                    if !record["previous_filename"].isNull {
                        guard let previous = Swift.String(record["previous_filename"] as JSON?),
                            !previous.isEmpty
                        else { throw .response }
                        previousPath = previous
                    } else {
                        previousPath = nil
                    }
                    changes.append(.init(path: path, previousPath: previousPath))
                }
            }
            return changes
        }

        static func objects(
            at endpoint: Swift.String,
            response: (Swift.String) throws(Error) -> JSON
        ) throws(Error) -> [[Swift.String: JSON]] {
            var objects: [[Swift.String: JSON]] = []
            for page in try pages(from: response(endpoint)) {
                guard let object = page.dictionary else { throw .response }
                objects.append(object)
            }
            return objects
        }

        static func response(at endpoint: Swift.String) throws(Error) -> JSON {
            let output: Process.Output
            do throws(Process.Error) {
                output = try Process.Spawn.run(
                    .init(
                        executable: "/usr/bin/env",
                        arguments: ["gh", "api", "--paginate", "--slurp", endpoint],
                        stdout: .pipe,
                        stderr: .pipe
                    )
                )
            } catch {
                throw .response
            }
            guard case .exited(let code) = output.status, code == 0 else { throw .response }
            let value: JSON
            do throws(JSON.Error) {
                value = try JSON.parse(
                    Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
                )
            } catch {
                throw .response
            }
            return value
        }

        static func pages(from value: JSON) throws(Error) -> [JSON] {
            guard let pages = value.array, !pages.isEmpty else { throw .response }
            return pages
        }

        static func packageRoots(in workspace: Swift.String) -> [Swift.String] {
            var roots: [Swift.String] = []
            walk(workspace, relative: "", into: &roots)
            return roots
        }

        private static func walk(
            _ directory: Swift.String,
            relative prefix: Swift.String,
            into roots: inout [Swift.String]
        ) {
            guard let entries = names(atPath: directory)?.sorted()
            else { return }
            for name in entries {
                if prefix.isEmpty, [".git", ".build", ".swiftpm"].contains(name) {
                    continue
                }
                let child = "\(directory)/\(name)"
                let relative = prefix.isEmpty ? name : "\(prefix)/\(name)"
                if isDirectory(atPath: child) {
                    if [".git", ".build", ".swiftpm"].contains(name) { continue }
                    walk(child, relative: relative, into: &roots)
                } else if name == "Package.swift" {
                    roots.append(prefix)
                }
            }
        }

        static func isZero(_ revision: Swift.String) -> Bool {
            revision.count == 40 && revision.allSatisfy { $0 == "0" }
        }

        // MARK: filesystem

        /// The UTF-8 text of the file at `path`, or `nil` when unreadable.
        static func text(atPath path: Swift.String) -> Swift.String? {
            guard let filePath = try? File.Path(path) else { return nil }
            do throws(Either<File.System.Read.Full.Error, Never>) {
                return try File(filePath).read.full { view in
                    var storage = [Byte]()
                    storage.reserveCapacity(view.count)
                    for index in view.indices {
                        storage.append(view[index])
                    }
                    return Swift.String(decoding: storage, as: Swift.UTF8.self)
                }
            } catch {
                return nil
            }
        }

        /// The entry names of the directory at `path`, or `nil` when the
        /// path is invalid, missing, or not a directory.
        static func names(atPath path: Swift.String) -> [Swift.String]? {
            guard let filePath = try? File.Path(path) else { return nil }
            guard let entries = try? File.Directory.Contents.list(at: .init(filePath)) else {
                return nil
            }
            return entries.map { Swift.String(lossy: $0.name) }
        }

        static func isDirectory(atPath path: Swift.String) -> Swift.Bool {
            guard let filePath = try? File.Path(path) else { return false }
            return File(filePath).stat.isDirectory
        }
    }
}
