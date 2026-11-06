public import Institute_Model
public import Package_Manager

extension Institute.Repository.Policy.BranchPin {
    public struct Finding: Swift.Sendable, Swift.Hashable {
        public let document: Swift.String
        public let url: Package.Manifest.Dependency.Location
        public let branch: Swift.String

        public init(document: Swift.String, url: Package.Manifest.Dependency.Location, branch: Swift.String) {
            self.document = document
            self.url = url
            self.branch = branch
        }
    }
}
