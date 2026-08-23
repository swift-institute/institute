import GitHub_Standard

// Nest.Name namespace shell. `GitHub.ContinuousIntegration` is the sole
// owner of the relation between continuous-integration semantics and
// GitHub's CI platform. The `GitHub` namespace itself is owned by
// swift-standards/swift-github-standard; this package extends it.
extension GitHub {
    public enum ContinuousIntegration {}
}
