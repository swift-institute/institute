public import Institute_Model

extension Institute.Repository.Policy.BrokenSymlink {
    public struct Finding: Sendable, Hashable {
        public let path: String

        public init(path: String) {
            self.path = path
        }
    }
}
