public import Institute_Model

extension Institute {
    /// Kernels of a package, written in a GPU's language into its generated files.
    public enum Shader {}
}

extension Institute.Shader {
    /// The swift.org release a kernel is compiled with, so that a file is the same whoever generates it.
    public static let release: Swift.String = "6.4.2"
}
