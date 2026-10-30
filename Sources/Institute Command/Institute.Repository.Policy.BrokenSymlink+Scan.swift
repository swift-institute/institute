import File_System
public import Institute_CI_Model
public import Institute_Model
public import Institute_Repository_Policy

extension Institute.Repository.Policy.BrokenSymlink {
    /// Broken symbolic links beneath `root`, in repository-relative order.
    public static func findings(at root: Swift.String) throws(Error) -> [Finding] {
        guard let initial = Institute.CI.Command.names(atPath: root) else {
            throw .unreadableRoot(root)
        }

        var findings: [Finding] = []
        var pending = initial
        while let path = pending.popLast() {
            let absolute = root + "/" + path
            guard let filePath = try? File.Path(absolute) else {
                throw .unreadablePath(path)
            }
            let stat = File(filePath).stat
            guard stat.isSymlink else {
                if stat.isDirectory {
                    guard let children = Institute.CI.Command.names(atPath: absolute) else {
                        throw .unreadablePath(path)
                    }
                    pending.append(contentsOf: children.map { path + "/" + $0 })
                }
                continue
            }
            if !stat.exists {
                findings.append(.init(path: path))
            }
        }
        return findings.sorted { $0.path < $1.path }
    }
}
