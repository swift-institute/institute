internal import File_System
public import Institute_Model

extension Institute.Inventory {
    /// The packages and repositories under a root, found by walking real
    /// directories only (symbolic links are not followed).
    public struct Discovery: Sendable {
        /// Directories never descended into.
        public static let skipped: Swift.Set<Swift.String> = [
            ".build", ".swiftpm", "checkouts", "DerivedData", ".claude", "node_modules", ".git",
        ]

        /// Package directories, relative to the root ("." for the root).
        public var packages: [Swift.String] = []
        /// Directories holding a `.git` directory or file, relative to the root.
        public var repositories: [Swift.String] = []

        public init(root: Swift.String, excluding excluded: [Swift.String]) {
            let excluded = excluded.map { $0.hasSuffix("/") ? Swift.String($0.dropLast()) : $0 }
            var stack = [""]
            while let relative = stack.popLast() {
                let absolute = relative.isEmpty ? root : root + "/" + relative
                guard let entries = Self.entries(at: absolute) else { continue }
                let name = relative.isEmpty ? "." : relative
                if entries.contains(where: { $0.name == "Package.swift" && $0.kind == .file }) {
                    packages.append(name)
                }
                if entries.contains(where: { $0.name == ".git" }) {
                    repositories.append(name)
                }
                for entry in entries where entry.kind == .directory && !Self.skipped.contains(entry.name) {
                    let child = relative.isEmpty ? entry.name : relative + "/" + entry.name
                    if excluded.contains(where: { child == $0 || child.hasPrefix($0 + "/") }) { continue }
                    stack.append(child)
                }
            }
            packages.sort()
            repositories.sort()
        }

        enum Kind { case file, directory, other }

        static func entries(at path: Swift.String) -> [(name: Swift.String, kind: Kind)]? {
            guard let filePath = try? File.Path(path),
                let entries = try? File.Directory.Contents.list(at: File.Directory(filePath))
            else { return nil }
            return entries.map { entry in
                let kind: Kind =
                    switch entry.type {
                    case .file: .file
                    case .directory: .directory
                    default: .other
                    }
                return (Swift.String(lossy: entry.name), kind)
            }
        }

        /// The Swift files under a target directory, relative to it, sorted.
        /// A subdirectory holding its own `Package.swift` is another package
        /// and is left out.
        static func swiftFiles(under directory: Swift.String) -> [Swift.String] {
            var files: [Swift.String] = []
            var stack = [""]
            while let relative = stack.popLast() {
                let absolute = relative.isEmpty ? directory : directory + "/" + relative
                guard let entries = entries(at: absolute) else { continue }
                if !relative.isEmpty, entries.contains(where: { $0.name == "Package.swift" && $0.kind == .file }) {
                    continue
                }
                for entry in entries {
                    let child = relative.isEmpty ? entry.name : relative + "/" + entry.name
                    switch entry.kind {
                    case .directory where !skipped.contains(entry.name): stack.append(child)
                    case .file where entry.name.hasSuffix(".swift"): files.append(child)
                    default: continue
                    }
                }
            }
            return files.sorted()
        }

        static func isDirectory(_ path: Swift.String) -> Swift.Bool {
            guard let filePath = try? File.Path(path) else { return false }
            return File(filePath).stat.isDirectory
        }

        static func text(at path: Swift.String) -> Swift.String? {
            guard let filePath = try? File.Path(path) else { return nil }
            do throws(Either<File.System.Read.Full.Error, Never>) {
                return try File(filePath).read.full { view in
                    var storage = [Swift.UInt8]()
                    storage.reserveCapacity(view.count)
                    for index in view.indices { storage.append(view[index].bitPattern) }
                    return Swift.String(decoding: storage, as: Swift.UTF8.self)
                }
            } catch {
                return nil
            }
        }
    }
}
