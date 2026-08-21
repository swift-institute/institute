internal import Byte_Primitives
internal import FIPS_180_4
public import File_System
public import Git_Foundation
public import Institute_Model
public import Source_Measurement

extension Institute.Source.Workspace {
    public static func subject(
        for row: Row,
        using git: Git.Client = .init()
    ) throws(Institute.Error) -> Source.Subject {
        let paths: [Swift.String]
        do throws(Git.Client.Error) { paths = try git.paths(at: row.directory) } catch {
            throw .filesystem("cannot enumerate Git paths for \(row.identity): \(error)")
        }
        return try subject(for: row, paths: paths)
    }

    public static func subject(
        for row: Row,
        paths: [Swift.String]
    ) throws(Institute.Error) -> Source.Subject {
        let root: File.Directory
        do throws(File.Path.Error) { root = File.Directory(try .init(row.directory)) } catch {
            throw .configuration("invalid source member path \(row.directory)")
        }
        guard root[file: "Package.swift"].stat.isFile else {
            throw .configuration("source member manifest is missing at \(row.directory)")
        }
        let rootCanonical: File.Path
        do throws(File.System.Canonical.Error) {
            rootCanonical = try File.System.Canonical.resolve(root.path)
        } catch { throw .filesystem("cannot canonicalize source root \(row.directory): \(error)") }

        var present: Swift.Set<Swift.String> = []
        var pending: [File.Directory] = [root]
        while let directory = pending.popLast() {
            do throws(File.Directory.Contents.Error) {
                for file in try directory.files() where file.path.description.hasSuffix(".swift") {
                    present.insert(relative(file.path, to: root.path).joined(separator: "/"))
                }
                for child in try directory.directories() {
                    guard !excluded(child.path, root: root.path) else { continue }
                    pending.append(child)
                }
            } catch {
                throw .filesystem("cannot enumerate source paths at \(directory): \(error)")
            }
        }

        var candidates = present
        candidates.insert("Package.swift")
        for path in paths where path.hasSuffix(".swift") { candidates.insert(path) }
        var canonicalFiles: Swift.Set<Swift.String> = []
        var artifacts: [Source.Artifact] = []
        for path in candidates.sorted() {
            guard valid(path) else { throw .configuration("invalid source artifact path \(path)") }
            let parsed: File.Path
            do throws(File.Path.Error) { parsed = try .init(path) } catch {
                throw .configuration("invalid source artifact path \(path)")
            }
            let file = File(root.path / parsed)
            guard file.stat.isFile, !file.stat.isSymlink else {
                throw .filesystem("source artifact is missing or not a regular file: \(path)")
            }
            let canonical: File.Path
            do throws(File.System.Canonical.Error) {
                canonical = try File.System.Canonical.resolve(file.path)
            } catch { throw .filesystem("cannot canonicalize source artifact \(path): \(error)") }
            let rootComponents = Array(rootCanonical.components)
            let fileComponents = Array(canonical.components)
            guard fileComponents.count > rootComponents.count,
                fileComponents.prefix(rootComponents.count).elementsEqual(rootComponents)
            else { throw .configuration("source artifact escapes workspace member: \(path)") }
            guard canonicalFiles.insert(canonical.description).inserted else {
                throw .configuration("duplicate canonical source artifact: \(path)")
            }
            artifacts.append(
                .init(
                    path: path,
                    kind: .swift,
                    provenance: .authored,
                    digest: try digest(file)
                )
            )
        }
        return .init(identity: row.identity, root: row.directory, artifacts: artifacts)
    }

    private static func relative(_ path: File.Path, to base: File.Path) -> [Swift.String] {
        let root = Array(base.components)
        let full = Array(path.components)
        guard full.count > root.count, full.prefix(root.count).elementsEqual(root) else {
            return full.map(\.string)
        }
        return full.dropFirst(root.count).map(\.string)
    }

    private static func digest(_ file: File) throws(Institute.Error) -> Source.Artifact.Digest {
        let bytes: [Byte]
        do throws(Either<File.System.Read.Full.Error, Never>) {
            bytes = try file.read.full { span in
                var result: [Byte] = []
                result.reserveCapacity(span.count)
                for index in span.indices { result.append(span[index]) }
                return result
            }
        } catch { throw .filesystem("cannot read source artifact \(file): \(error)") }
        return .init(FIPS_180_4.SHA256.digest(bytes).hex)
    }

    private static func excluded(_ path: File.Path, root: File.Path) -> Swift.Bool {
        let components = relative(path, to: root)
        return components.contains { [".git", ".build", ".swiftpm"].contains($0) }
    }

    private static func valid(_ path: Swift.String) -> Swift.Bool {
        guard !path.isEmpty, !path.hasPrefix("/") else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return !components.contains { $0.isEmpty || $0 == "." || $0 == ".." }
    }
}
