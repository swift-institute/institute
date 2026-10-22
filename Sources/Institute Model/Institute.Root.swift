public import File_System
private import Kernel

extension Institute {
    /// The two filesystem roots that define one Institute checkout.
    ///
    /// ``checkout`` owns configuration and generated checkout-local state.
    /// ``hierarchy`` is exactly the physical checkout's parent and owns the
    /// materialized organization roots.
    public struct Root: Sendable {
        public let checkout: File.Directory
        public let hierarchy: File.Directory

        /// Resolves the starting directory physically, discovers the containing
        /// checkout by its inventory and context roots, and derives its hierarchy parent.
        ///
        /// No initializer accepts the two roots independently: their
        /// parent-child relationship is the invariant this value carries.
        public init(checkout: File.Directory) throws(Institute.Error) {
            let path: File.Path
            do throws(File.System.Canonical.Error) {
                path = try File.System.Canonical.resolve(checkout.path)
            } catch {
                throw .configuration("cannot resolve the workspace checkout \(checkout): \(error)")
            }

            let info: File.System.Metadata.Info
            do throws(Kernel.File.Stats.Error) {
                info = try File.System.Stat.info(at: path, followSymlinks: false)
            } catch {
                throw .configuration("cannot inspect the workspace checkout \(path): \(error)")
            }
            guard info.type == .directory else {
                throw .configuration("workspace checkout is not a directory: \(path)")
            }

            let starting = File.Directory(path)
            var physical = starting
            while !physical[file: "Institute.json"].stat.isFile
                || !physical[directory: "Context"].stat.isDirectory
            {
                guard let parent = physical.parent else {
                    throw .configuration("not inside an Institute checkout: \(starting)")
                }
                physical = parent
            }

            guard let hierarchy = physical.parent else {
                throw .configuration("Institute checkout has no hierarchy parent: \(physical)")
            }

            self.checkout = physical
            self.hierarchy = hierarchy
        }
    }
}
