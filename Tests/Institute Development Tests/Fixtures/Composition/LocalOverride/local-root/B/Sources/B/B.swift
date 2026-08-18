public enum B {
    public static func origin() -> Swift.String { "LOCAL_OVERRIDE" }

    /// Exists only in the local copy. A consumer referencing it can
    /// compile exactly when the local override won resolution — the
    /// admissible positive control; manifest text proves nothing.
    public static func localOnly() -> Swift.String { "LOCAL_ONLY" }
}
