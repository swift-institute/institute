public import Institute_Model

extension Institute.Repository.Policy {
    /// The root manifest documents of one package checkout: every
    /// `Package.swift` variant beside the checkout root, and the root
    /// `Package.resolved` when there is one. The dependency and identity
    /// policies read their facts from this value, not from the disk.
    public struct Manifest: Sendable, Equatable {
        /// Root manifests, sorted by document name.
        public let documents: [Document]
        /// The root `Package.resolved` text, or `nil` when absent or unreadable.
        public let resolved: String?

        public init(documents: [Document], resolved: String?) {
            self.documents = documents.sorted { $0.name < $1.name }
            self.resolved = resolved
        }
    }
}

extension Institute.Repository.Policy.Manifest {
    public struct Document: Sendable, Equatable {
        public let name: String
        public let source: String

        public init(name: String, source: String) {
            self.name = name
            self.source = source
        }
    }
}
