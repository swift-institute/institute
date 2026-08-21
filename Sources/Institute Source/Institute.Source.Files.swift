public import File_System
public import Institute_Model
public import Source_Measurement

extension Institute.Source.Application {
    public func subject(for row: Institute.Source.Workspace.Row) throws(Institute.Error) -> SourceDomain.Subject {
        let root: File.Directory
        do throws(File.Path.Error) { root = File.Directory(try .init(row.directory)) }
        catch { throw .configuration("invalid source member path \(row.directory)") }

        var files: [Swift.String] = []
        for component: File.Path.Component in ["Sources", "Tests"] {
            let directory = root[directory: component]
            guard directory.stat.isDirectory else { continue }
            do throws(File.Directory.Walk.Error) {
                try directory.walk.files { file in
                    let components = Self.relative(file.path, to: root.path)
                    guard components.last?.hasSuffix(".swift") == true else { return .continue }
                    guard !Self.excluded(components) else { return .continue }
                    files.append(components.joined(separator: "/"))
                    return .continue
                }
            } catch {
                throw .filesystem("cannot enumerate Swift sources at \(directory): \(error)")
            }
        }
        return .init(identity: row.identity, root: row.directory, files: files)
    }

    private static func relative(_ path: File.Path, to base: File.Path) -> [Swift.String] {
        let root = Array(base.components)
        let full = Array(path.components)
        guard full.count > root.count, full.prefix(root.count).elementsEqual(root) else {
            return full.map(\.string)
        }
        return full.dropFirst(root.count).map(\.string)
    }

    private static func excluded(_ components: [Swift.String]) -> Swift.Bool {
        if components.contains(".build") || components.contains(".swiftpm") { return true }
        for index in components.indices where components[index].hasSuffix(".docc") {
            if components.dropFirst(index + 1).contains("Resources") { return true }
        }
        return components.starts(with: ["Tests", "Support"])
            || components.starts(with: ["Tests", "Tutorial"])
    }
}
