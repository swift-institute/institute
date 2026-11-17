public import Institute_CI_Model
public import Institute_Model

extension Institute.CI.Canon.Gitignore {
    /// Exact generated policy for a declared nested test or benchmark package.
    public enum Nested {
        public static let text = """
            .build/
            .swiftpm/
            .benchmarks/

            """

        /// The only locations at which a nested package policy may be declared.
        public static let roots = ["Tests", "Benchmarks"]

        /// The suffixes that name a product's leaf: a root folder holding a
        /// nested package of its own, under the product's whole canon.
        public static let leaves = ["-app", "-server", "-film", "-cli"]

        // swift-linter:disable:next raw concept
        // REASON: a root folder's name as the directory listing gives it, compared by suffix only, never opened.
        public static func isLeaf(_ name: String) -> Bool {
            leaves.contains { name.hasSuffix($0) && name.count > $0.count }
        }

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
