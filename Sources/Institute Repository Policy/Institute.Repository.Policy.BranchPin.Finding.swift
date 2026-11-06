public import Institute_Model

extension Institute.Repository.Policy.BranchPin {
    public struct Finding: Swift.Sendable, Swift.Hashable {
        public let document: Swift.String
        // swift-linter:disable:next raw concept
        // REASON: a dependency's URL as Package.Manifest.Dependency.SourceControl holds it, quoted back in a finding; SwiftPM admits git@host:org/repo forms, which organization(of:) reads and RFC_3986.URI and WHATWG_URL.URL refuse.
        public let url: Swift.String
        public let branch: Swift.String

        // swift-linter:disable:next raw concept
        // REASON: a dependency's URL as Package.Manifest.Dependency.SourceControl holds it, quoted back in a finding; SwiftPM admits git@host:org/repo forms, which organization(of:) reads and RFC_3986.URI and WHATWG_URL.URL refuse.
        public init(document: Swift.String, url: Swift.String, branch: Swift.String) {
            self.document = document
            self.url = url
            self.branch = branch
        }
    }
}
