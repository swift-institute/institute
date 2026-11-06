public import File_System
public import Institute_Model

extension Institute.Repository.Policy.BrokenSymlink {
    public struct Finding: Sendable, Hashable {
        public let path: File.Path

        public init(path: File.Path) {
            self.path = path
        }
    }
}
