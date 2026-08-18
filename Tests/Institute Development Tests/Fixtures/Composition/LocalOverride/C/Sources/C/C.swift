import A
import B

public enum C {
    /// Compiles exactly when the LOCAL copy of `B` won resolution:
    /// `localOnly()` does not exist in the remote copy.
    public static func proof() -> Swift.String { A.sees() + B.localOnly() }
}
