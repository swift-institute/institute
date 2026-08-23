import Institute_CI_Model

extension ContinuousIntegration.Canon.Gitignore {
    /// Exact generated policy for a declared nested test or benchmark package.
    public enum Nested {
        public static let text = """
            .build/
            .swiftpm/
            .benchmarks/

            """

        /// The only locations at which a nested package policy may be declared.
        public static let roots = ["Tests", "Benchmarks"]

        /// Exact policy paths generated from declared nested manifests.
        public static func policies(declarations: [String]) -> [String: String] {
            Dictionary(
                uniqueKeysWithValues: roots.compactMap { root in
                    declarations.contains("\(root)/Package.swift")
                        ? ("\(root)/.gitignore", text) : nil
                }
            )
        }
    }
}
